Async = require("async")
redis = require("../config/redis")


# A split test.  A split test records any number of participants, which
# alternative was presented to each one, and if they converted, the outcome.
#
# Each participant is known by its unique identifier.  The alternative is a
# number starting with zero for the first alternative.   When the participant
# first joins the split test, the alternative is stored and cannot change
# afterwards.  In addition, the timestamp is also recorded.
#
# At some point the participant converts, and we record the outcome (a numeric
# value) and timestamp.  Only the first such occurrence is stored.
class SplitTest


  # -- Storage --
  #
  # vanity.split.:test hash records general information about the test: its
  # title and created timestamp.
  #
  # vanity.split.:test.:alt is a hash with information about the alternative:
  # its title, number of participants and number of completions.
  #
  # vanity.split.:test.participants maps each participant into an alternative (0
  # or 1). We use this to note a participant has joined the test, so we don't
  # add the same participant twice, and to note what alternative was assigned to
  # them.
  #
  # vanity.split.:test.joined sorted set records when each participant joined
  # the test. The score is the time at which the participant was recorded. We
  # use this to attribute conversion to particular hour of a day.
  #
  # vanity.split.:test.completed set contains all participants that completed
  # the test. We use this to avoid counting the same participant twice (i.e.
  # only allow single conversion).
  #
  # vanity.split.:test.converted.:alt hash records how many participants that
  # joined in a given hour also completed the test.  The key is an hour
  # (RFC3339) and the value is the count.
 

  # Create a new split test with the given identifier.  Throws exception is the
  # identifier is invalid.
  constructor: (@id)->
    unless @id && /^[\w\-]+$/.test(@id)
      throw new Error("Split test identifier may only contain alphanumeric, underscore and hyphen")
    @_base_key = "#{redis.prefix}.split.#{@id}"


  # Update test to note when it was first used.
  created: (callback)->
    multi = redis.multi()
    # This will set the created timestamp the first time we call created.
    multi.hsetnx @_base_key, "created", Date.create().toISOString()
    # Make sure test always has a title
    multi.hsetnx @_base_key, "title", @id.titleize()
    multi.exec callback


  # Adds a participant.
  #
  # participant - Participant identifier
  # alternative - Alternative (A is false, B is true)
  # callback    - Receive error or response
  #
  # Throws an exception if participant identifier or alternative number are
  # invalid.
  #
  # Callback result has:
  # participant - Participant identifier
  # alternative - Alternative number
  #
  # Note that only the first alternative number is stored, and the alternative
  # passed to the callback is that first value.
  addParticipant: (participant, alternative, callback)->
    participant = participant.toString() unless Object.isString(participant)
    alternative = alternative && 1 || 0

    # Make sure we take note of the experiment.
    @created (error)=>
      return callback(error) if error

      # First check if we already know which alternative was presented.
      redis.hget "#{@_base_key}.participants", participant, (error, known)=>
        return callback(error) if error
        if known != null
          # We've seen this participant before, nothing more to do.
          callback error,
            participant:  participant
            alternative:  parseInt(known)
          return

        # First we assign the participant an alternative, and we do it using
        # HSETNX to avoid a race condition.
        redis.hsetnx "#{@_base_key}.participants", participant, alternative, (error, changed)=>
          return callback(error) if error
          unless changed # Someone beat us to it
            @getParticipant participant, callback
            return

          # Update alternative stats, we've got one more participant to account
          # for.  Record when participant joined, so later on we can count a
          # conversion against that.
          multi = redis.multi()
          multi.hincrby "#{@_base_key}.#{alternative}", "participants", 1
          multi.zadd "#{@_base_key}.joined", Date.now(), participant
          multi.exec (error)->
            callback error,
              participant:  participant
              alternative:  alternative
    return

 
  # Indicates participant completed the test.
  #
  # participant - Participant identifier
  # callback    - Receive error or null
  completed: (participant, callback)->
    participant = participant.toString() unless Object.isString(participant)

    redis.sadd "#{@_base_key}.completed", participant, (error, added)=>
      return callback(error) if error
      unless added
        # This participant already recorded as completed, nothing more to do.
        callback()
        return

      # First check if we already know which alternative was presented.
      redis.hget "#{@_base_key}.participants", participant, (error, alternative)=>
        return callback(error) if error
        if alternative == null
          # Never seen this participant, so ignore
          callback()
          return

        # Next we need to know when participant joined, so we can record a
        # conversion for that time period.
        redis.zscore "#{@_base_key}.joined", participant, (error, score)=>
          return callback(error) if error
          if score == null
            callback()
            return
          joined = new Date(parseInt(score))

          # Update alternative stats, we've got one more completion to account
          # for.  Also, increment one conversion based on when participant was
          # joined the test.
          multi = redis.multi()
          multi.hincrby "#{@_base_key}.#{alternative}", "completed", 1
          hour = joined.set(minute: 0, true).toISOString()
          multi.hincrby "#{@_base_key}.converted.#{alternative}", hour, 1
          multi.exec callback
    return


  # Retrieves information about a participant.
  #
  # participant - Participant identifier
  #
  # Callback recieves error and result object with:
  # participant - Participant identifier
  # alternative - Alternative number
  # joined      - When participant joined the test (Date)
  # completed   - When participant completed the test (Date)
  #
  # If the participant never joined this split test, the callback receives null.
  getParticipant: (participant, callback)->
    redis.hget "#{@_base_key}.participants", participant, (error, alternative)=>
      return callback(error) if error
      if alternative == null
        # Identifier doesn't match any participant
        callback()
        return

      # Get when participant joined this test
      redis.zscore "#{@_base_key}.joined", participant, (error, score)=>
        return callback(error) if error
        # Get when participant compeleted this test
        redis.sismember "#{@_base_key}.completed", participant, (error, completed)->
          return callback(error) if error
          callback null,
            participant:  participant
            alternative:  alternative
            joined:       new Date(parseInt(score))
            completed:    !!completed


  # Use this to load a test into memory.  Passes SplitTest object to callback,
  # or null if test doesn't exist.
  #
  # The SplitTest properties include:
  # title         - Humand readable title
  # created       - Date/time when test was created
  @load: (id, callback)->
    try
      test = new SplitTest(id)
      test.load (error)->
        if test.title && test.alternatives
          callback null, test
        else
          callback null
    catch error
      callback error

  # Load test into memory.  Used by SplitTest.load and after an update.
  load: (callback)->
    Async.parallel [
      (done)=>
        redis.hgetall @_base_key, done
    , (done)=>
        redis.lrange "#{@_base_key}.alternatives", 0, -1, done
    , (done)=>
        redis.lrange "#{@_base_key}.weights", 0, -1, done
    ], (error, [hash, titles, weights])=>
      if (error)
        callback(error)
      else
        if hash
          @title = hash.title
          @created = hash.created
        if titles && weights
          @alternatives = titles.map((title, i)-> { title: title, weight: weights[i] })
        callback(null)


  # Loads test data and passes callback array with one element for each
  # alternative, containing:
  # title   - Alternative title
  # weight  - Designated weight
  # data    - Data points
  #
  # Each data point has the properties:
  # time          - Time stamp (in hour increments) RFC3999
  # participants  - How many participants joined during that hour
  # completed     - How many of these participants completed the test
  @data: (id, callback)->
    base_key = "#{redis.prefix}.split.#{id}"
    Async.waterfall [
      (done)->
        # First we need to determine which participant is assigned what
        # alternative. This gives us a map from participant ID to alternative
        # number.
        redis.hgetall "#{base_key}.participants", done

    , (participants, doneJoined)->
        # Next we need to determine how many participants joined each
        # alternative in any given hour.
        hourly = [{}, {}]
        redis.zrange "#{base_key}.joined", 0, -1, "withscores", (error, joined)->
          return doneJoined(error) if error
          for [id, time] in joined.inGroupsOf(2)
            time -= time % 3600000 # round down to nearest hour
            set = hourly[participants[id]]
            hour = set[time] ||= { time: Date.create(time).toISOString() }
            hour.participants = (hour.participants || 0) + 1
          doneJoined(null, hourly)

    , (hourly, doneConverted)->
        # Load everything we know about conversion for each given time slot, and
        # update the data record.
        Async.map [0, 1], (alternative, doneEach)->
          set = hourly[alternative]
          redis.hgetall "#{base_key}.converted.#{alternative}", (error, converted)->
            return doneEach(error) if error
            for time, entry of set
              converted = converted[entry.time] || 0
              entry.converted = converted
            doneEach(null, set)
        , doneConverted

    , (hourly, done)->
        # Now let's turn each hourly map into a sorted array.
        sorted = (Object.values(set).sort("time") for set in hourly)
        done(null, sorted)

    ], callback


module.exports = SplitTest
