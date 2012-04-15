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
SplitTest =


  # -- Storage --
  #
  # vanity.split set contains the name of each active test.
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


  # -- Participants --

  # Adds a participant.
  #
  # test_id     - Split test identifier
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
  participated: (test_id, participant, alternative, callback)->
    participant = participant.toString() unless Object.isString(participant)
    alternative = alternative && 1 || 0
    base_key = SplitTest.baseKey(test_id)

    # Make sure we take note of the experiment.
    SplitTest.create test_id, (error)->
      return callback(error) if error

      # First check if we already know which alternative was presented.
      redis.hget "#{base_key}.participants", participant, (error, known)->
        return callback(error) if error
        if known != null
          # We've seen this participant before, nothing more to do.
          callback error,
            participant:  participant
            alternative:  parseInt(known)
          return

        # First we assign the participant an alternative, and we do it using
        # HSETNX to avoid a race condition.
        redis.hsetnx "#{base_key}.participants", participant, alternative, (error, changed)->
          return callback(error) if error
          unless changed # Someone beat us to it
            SplitTest.getParticipant test_id, participant, callback
            return

          # Update alternative stats, we've got one more participant to account
          # for.  Record when participant joined, so later on we can count a
          # conversion against that.
          multi = redis.multi()
          multi.hincrby "#{base_key}.#{alternative}", "participants", 1
          multi.zadd "#{base_key}.joined", Date.now(), participant
          multi.exec (error)->
            callback error,
              participant:  participant
              alternative:  alternative
    return


  # Retrieves information about a participant.
  #
  # test_id     - Split test identifier
  # participant - Participant identifier
  #
  # Callback recieves error and result object with:
  # participant - Participant identifier
  # alternative - Alternative number
  # joined      - When participant joined the test (Date)
  # completed   - When participant completed the test (Date)
  #
  # If the participant never joined this split test, the callback receives null.
  getParticipant: (test_id, participant, callback)->
    base_key = SplitTest.baseKey(test_id)
    redis.hget "#{base_key}.participants", participant, (error, alternative)->
      return callback(error) if error
      if alternative == null
        # Identifier doesn't match any participant
        callback()
        return

      # Get when participant joined this test
      redis.zscore "#{base_key}.joined", participant, (error, score)->
        return callback(error) if error
        # Get when participant compeleted this test
        redis.sismember "#{base_key}.completed", participant, (error, completed)->
          return callback(error) if error
          callback null,
            participant:  participant
            alternative:  alternative
            joined:       new Date(parseInt(score))
            completed:    !!completed


  # Indicates participant completed the test.
  #
  # test_id     - Split test identifier
  # participant - Participant identifier
  # callback    - Receive error or null
  completed: (test_id, participant, callback)->
    participant = participant.toString() unless Object.isString(participant)
    base_key = SplitTest.baseKey(test_id)

    redis.sadd "#{base_key}.completed", participant, (error, added)->
      return callback(error) if error
      unless added
        # This participant already recorded as completed, nothing more to do.
        callback()
        return

      # First check if we already know which alternative was presented.
      redis.hget "#{base_key}.participants", participant, (error, alternative)->
        return callback(error) if error
        if alternative == null
          # Never seen this participant, so ignore
          callback()
          return

        # Next we need to know when participant joined, so we can record a
        # conversion for that time period.
        redis.zscore "#{base_key}.joined", participant, (error, score)->
          return callback(error) if error
          if score == null
            callback()
            return
          joined = new Date(parseInt(score))

          # Update alternative stats, we've got one more completion to account
          # for.  Also, increment one conversion based on when participant was
          # joined the test.
          multi = redis.multi()
          multi.hincrby "#{base_key}.#{alternative}", "completed", 1
          hour = joined.set(minute: 0, true).toISOString()
          multi.hincrby "#{base_key}.converted.#{alternative}", hour, 1
          multi.exec (error)->
            callback(error)
    return


  # -- Tests --

  # Use this to list all known split tests.
  #
  # Passes callback an array with one element for each test, consisting of:
  # id            - Test identifier
  # title         - Humand readable title
  # created       - Time when test was created
  # alternatives  - Array with information about each alternative
  #   participants - Number of participants
  #   complete     - Number that completed the test
  list: (callback)->
    redis.smembers "#{redis.prefix}.split", (error, ids)->
      return callback(error) if error
      # Use multi to load everything in one go
      multi = redis.multi()
      for id in ids
        multi.hgetall "#{redis.prefix}.split.#{id}"
        multi.hgetall "#{redis.prefix}.split.#{id}.0"
        multi.hgetall "#{redis.prefix}.split.#{id}.1"
      multi.exec (error, data)->
        return callback(error) if error
        callback null, data.inGroupsOf(3).map(([test, a, b], i)->
          id:      ids[i]
          title:   test.title
          created: Date.create(test.created)
          alternatives: [a,b].map(({ title, participants, completed }, i)->
            participants: parseInt(participants) || 0
            completed:    parseInt(completed) || 0
            title:        title || "AB"[i]
          )
        )


  # Use this to load a test into memory.  Passes SplitTest object to callback,
  # or null if test doesn't exist.
  #
  # The SplitTest properties include:
  # title         - Humand readable title
  # created       - Date/time when test was created
  load: (test_id, callback)->
    base_key = SplitTest.baseKey(test_id)
    # Use multi to load everything in one go
    multi = redis.multi()
    multi.hgetall "#{base_key}"
    multi.hgetall "#{base_key}.0"
    multi.hgetall "#{base_key}.1"
    multi.hgetall "#{base_key}.participants"
    multi.zrange  "#{base_key}.joined", 0, -1, "withscores"
    multi.hgetall "#{base_key}.converted.0"
    multi.hgetall "#{base_key}.converted.1"
    multi.exec (error, [test, a, b, participants, joined, converted_a, converted_b])->
      converted = [converted_a, converted_b]
      return callback(error) if error
      unless test?.title # no such test
        callback(null)
        return

      # Next we need to determine how many participants joined each
      # alternative in any given hour.
      hourly = [{}, {}]
      for [id, time] in joined.inGroupsOf(2)
        time -= time % 3600000 # round down to nearest hour
        set = hourly[participants[id]]
        hour = set[time] ||= { time: Date.create(time).toISOString() }
        hour.participants = (hour.participants || 0) + 1

      # And from that we can determine how many converted in each hour.
      [0, 1].each (alternative)->
        set = hourly[alternative]
        for _, entry of set
          entry.converted = parseInt(converted[alternative][entry.time]) || 0

      callback null,
        id:       test_id
        title:    test.title
        created:  Date.create(test.created)
        alternatives: [a,b].map(({ participants, completed, title }, alternative)->
          participants: parseInt(participants) || 0
          completed:    parseInt(completed) || 0
          title:        title || "AB"[alternative]
          data:         Object.values(hourly[alternative]).sort("time")
        )


  # -- Utility --

  # Returns Redis key from split test identifier.  Also validates the
  # identifier, so this method raises an exception if the identifier is
  # invalid.
  baseKey: (test_id)->
    unless test_id && /^[\w\-]+$/.test(test_id)
      throw new Error("Split test identifier may only contain alphanumeric, underscore and hyphen")
    return "#{redis.prefix}.split.#{test_id}"


  # Update test to note when it was first used.
  create: (test_id, callback)->
    base_key = SplitTest.baseKey(test_id)
    multi = redis.multi()
    # This will set the created timestamp the first time we call created.
    multi.hsetnx base_key, "created", Date.create().toISOString()
    # Make sure test always has a title
    multi.hsetnx base_key, "title", test_id.titleize()
    # Also add test to the index
    multi.sadd "#{redis.prefix}.split", test_id
    multi.exec callback


module.exports = SplitTest
