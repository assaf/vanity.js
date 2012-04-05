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


  # Storage
  #
  # vanity.split.:test hash records general information about the test: its
  # title and creation timestamp.
  #
  # vanity.split.:test.alternatives list names all the alternatives by their
  # numeric order.
  #
  # vanity.split.:test.weights list specifies each alternative's weight.
  #
  # vanity.split.:test.participants hash maps participant identifier to
  # alternative number.  We use this to note that a participant joined the test
  # and what alternative was shown to them.
  #
  # vanity.split.:test.joined.:alt sorted set records when each participant
  # joined that test, using the timestamp as the score.  That allows us to
  # retrieve all participants for a given time range.  Having a set for each
  # alternative also makes it cheap to count participants for each alternative.
  #
  # If failure happens, it is possible that a participant will be recorded in
  # the hash but not the sorted set.  This is rare enough to not skew any
  # numbers, but statistics should always be presented from a consisted set
  # (i.e. the joined sorted set).
  #
  # vanity.split.:test.outcomes hash maps participant identifier to outcome
  # value.  We use it to nore that a participant completed the test and with
  # what outcome.
  #
  # vanity.split.:test.completed.:alt sorted set records when each participant
  # completed the test.  As with joined sorted set, it allows us to perform
  # quick counts for each alternative.
  #
  # If failure happens, it is possible that a participant outcome will be
  # recorded in the hash but not the sorted set.
 

  # Create a new split test with the given identifier.  Throws exception is the
  # identifier is invalid.
  constructor: (@id)->
    unless @id && /^[\w\-]+$/.test(@id)
      throw new Error("Split test identifier may only contain alphanumeric, underscore and hyphen")
    @_base_key = "#{redis.prefix}.split.#{@id}"


  # Adds a participant.
  #
  # Arguments are:
  # participant - Participant identifier
  # alternative - Alternative number
  # callback    - Receive error or response
  #
  # Throws an exception if participant identifier or alternative number are
  # invalid.
  #
  # Callback recieves error and result object with:
  # participant - Participant identifier
  # alternative - Alternative number
  #
  # Note that only the first alternative number is stored, and the alternative
  # passed to the callback is that first value.
  addParticipant: (participant, alternative, callback)->
    participant = participant.toString() unless Object.isString(participant)

    unless Object.isNumber(alternative)
      throw new Error("Missing alternative number")
    if alternative < 0
      throw new Error("Alternative cannot be a negative number")
    unless alternative == Math.floor(alternative)
      throw new Error("Alternative must be an integer")

    # First check if we already know which alternative was presented.
    redis.hget "#{@_base_key}.participants", participant, (error, known)=>
      return callback(error) if error
      if known != null
        # Respond with identifier and alternative
        callback error,
          participant:  participant
          alternative:  parseInt(known)
        return

      # Set the alternative if not already set (avoid race condition).
      redis.hsetnx "#{@_base_key}.participants", participant, alternative, (error, changed)=>
        return callback(error) if error
        unless changed # Someone beat us to it
          @getParticipant participant, callback
          return

        # Keep record of when participant joined
        redis.zadd "#{@_base_key}.joined.#{alternative}", Date.now(), participant, (error)->
          callback error,
            participant:  participant
            alternative:  alternative
    return

  
  # Sets the outcome, but also adds participant if not already in this split
  # test.
  #
  # Arguments are:
  # participant - Participant identifier
  # alternative - Alternative number
  # outcome     - Outcome
  # callback    - Receive error or response
  #
  # Throws an exception if participant identifier, alternative number or outcome
  # are invalid.
  #
  # Callback recieves error and result object with:
  # participant - Participant identifier
  # alternative - Alternative number
  # outcome     - Outcome
  #
  # Note that only the first alternative number and outcomes are stored, and the
  # values passed to the callback are those first stored.
  setOutcome: (participant, alternative, outcome, callback)->
    unless outcome == null || outcome == undefined || Object.isNumber(outcome)
      throw new Error("Outcome must be numeric value")

    @addParticipant participant, alternative, (error, result)=>
      return callback(error) if error
      if outcome == null || outcome == undefined
        callback null, result
        return

      redis.hsetnx "#{@_base_key}.outcomes", participant, outcome, (error, changed)=>
        return callback(error) if error
        unless changed # Someone beat us to it
          @getParticipant participant, callback
          return

        result.outcome = outcome
        redis.zadd "#{@_base_key}.completed.#{result.alternative}", Date.now(), participant, (error)->
          callback error, result


  # Retrieves information about a participant.
  #
  # Arguments are:
  # participant - Participant identifier
  #
  # Callback recieves error and result object with:
  # participant - Participant identifier
  # alternative - Alternative number
  # joined      - When participant joined the test (Date)
  # outcome     - Outcome
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
      redis.zscore "#{@_base_key}.joined.#{alternative}", participant, (error, score)=>
        return callback(error) if error
        # We have enough result for participant with no outcome
        result =
          participant:  participant
          alternative:  parseInt(alternative)
          joined:       new Date(parseInt(score))

        redis.hget "#{@_base_key}.outcomes", participant, (error, outcome)=>
          return callback(error) if error
          if outcome == null
            # Participant did not converat
            callback(null, result)
            return

          result.outcome = outcome
          # Get when participant compeleted this test
          redis.zscore "#{@_base_key}.completed.#{alternative}", participant, (error, score)->
            return callback(error) if error
            result.completed = new Date(parseInt(score))
            callback null, result


  # Use this to load a test into memory.  Passes SplitTest object to callback,
  # or null if test doesn't exist.
  #
  # The SplitTest properties include:
  # title         - Humand readable title
  # created       - Date/time when test was created
  # alternatives  - Lists all the title and weight of each alternative
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
    Async.parallel [
      (done)->
        redis.lrange "#{base_key}.alternatives", 0, -1, done
    , (done)->
        redis.lrange "#{base_key}.weights", 0, -1, done
    ], (error, [titles, weights])=>
      return callback(error) if error

      alternatives = titles.map((title, i)-> { title: title, weight: weights[i] })
      indices = alternatives.map((d, i)-> i)
      Async.waterfall [
        (done)->
          # Load all the participants that ever completed the test and key on
          # them.
          redis.hkeys "#{base_key}.outcomes", (error, participants)->
            completed = participants.reduce((hash, id)->
              hash[id] = true
              return hash
            , {})
            done(null, completed)
      , (completed, doneJoined)->
          Async.map indices, (index, doneMap)->
            redis.zrange "#{base_key}.joined.#{index}", 0, -1, "withscores", (error, joined)->
              return callback(error) if error
              # Convert id, ts, id, ts, id, ts sequence into a object with time
              # (rounded to hour) as the key and count of participants as value
              data = {}
              for [id, time] in joined.inGroupsOf(2)
                time -= time % 3600000
                obj = data[time] ||= { time: Date.create(time) }
                # Count one participant, and count once if completed
                obj.participants = (obj.participants || 0) + 1
                obj.completed ||= 0
                if completed[id]
                  obj.completed += 1
              doneMap(null, data)
          , doneJoined
      , (datum, done)->
          sorted = (Object.values(data).sort("time") for data in datum)
          done null, sorted
      ], (error, datum)->
        return callback(error) if error
        for i, data of datum
          alternatives[i].data = data
        callback null, alternatives


  update: (params, callback)->
    update = {}

    if params.title
      unless Object.isString(params.title)
        throw new Error("Title must be a string")
      update.title = params.title

    if params.alternatives
      if Object.isNumber(params.alternatives)
        # Create specified number of alternatives, evenly distributed
        count = Math.floor(params.alternatives)
        unless count > 1
          throw new Error("Split test must have 2 or more alternatives")
        if count > 10
          throw new Error("Split test with 10 alternatives makes no sense")
        alternatives = (1).upto(count).map((i)-> { title: (i + 64).chr() })
      else if Array.isArray(params.alternatives)
        # Map supplied array of alternatives (titles or titles + weights)
        alternatives = []
        for alt in params.alternatives
          if Object.isString(alt)
            alternatives.push { title: alt, weight: null }
          else if Array.isArray(alt)
            unless String.isString(alt[0])
              throw new Error("Alternative must be [title, weight], title must be a string")
            weight = parseInt(alt[1])
            unless weight >= 0 && weight <= 1
              throw new Error("Alternative must be [title, weight], weight must be value between 0 and 1")
            alternatives.push { title: alt[0], weight: weight }
        if alternatives.length > 10
          throw new Error("Split test with 10 alternatives makes no sense")
    else
      # Default to two alternatives, A and B.
      alternatives = [ { title: "A" }, { title: "B" } ]

    # Step one, determine how much weight was specified
    combined = 0
    unspecified = 0
    for alt in alternatives
      if alt.weight == undefined || alt.weight == null
        unspecified += 1
      else
        if alt.weight < 0 || alt.weight > 1
          throw new Error("Alternative weight must be value between 0 and 1 (inclusive)")
        combined += alt.weight
    if combined > 1
      throw new Error("The combined weight of all alternatives can't surpass 1")
    if unspecified > 0
      fraction = (1 - combined) / unspecified
      for alt in alternatives
        if alt.weight == undefined || alt.weight == null
          alt.weight = fraction
          combined += fraction
    if combined < 1
      alternatives[0].weight += 1 - combined


    multi = redis.multi()
    multi.hsetnx @_base_key, "created", Date.create().toISOString()
    # Make sure test always has a title
    multi.hsetnx @_base_key, "title", @id.titleize()
    unless Object.isEmpty(update)
      multi.hmset @_base_key, update
    multi.del "#{@_base_key}.alternatives"
    multi.del "#{@_base_key}.weights"
    for i, alt of alternatives
      multi.rpush "#{@_base_key}.alternatives", alt.title
      multi.rpush "#{@_base_key}.weights", alt.weight
    multi.exec (error)=>
      if error
        callback(error)
      else
        @load callback

 
module.exports = SplitTest
