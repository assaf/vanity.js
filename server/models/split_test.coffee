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
  # The hash vanity.split.:test.participants is a map from participant
  # identifier to alternative number.  We use this to note that a participant
  # joined the test and what alternative was shown to them.
  #
  # The sorted set vanity.split.:test.joined.:alt stores when each participant
  # joined that test, using the timestamp as the score.  That allows us to
  # retrieve all participants for a given time range.  Having a set for each
  # alternative also makes it cheap to count participants for each alternative.
  #
  # If failure happens, it is possible that a participant will be recorded in
  # the hash but not the sorted set.  This is rare enough to not skew any
  # numbers, but statistics should always be presented from a consisted set
  # (i.e. the joined sorted set).
  #
  # The hash vanity.split.:test.outcome is a map from participant identifier to
  # outcome value.  We use it to nore that a participant completed the test and
  # with what outcome.
  #
  # The sorted set vanity.split.:test.completed.:alt stores when each
  # participant completed the test.  As with joined sorted set, it allows us to
  # perform quick counts for each alternative.
  #
  # If failure happens, it is possible that a participant outcome will be
  # recorded in the hash but not the sorted set.
  

  # Namespace
  @NAMESPACE = "vanity.split"

  # Create a new split test with the given identifier.  Throws exception is the
  # identifier is invalid.
  constructor: (id)->
    unless id && /^[\w]+$/.test(id)
      throw new Error("Split test identifier may only contain alphanumeric, underscore and hyphen")
    @_base_key = "#{SplitTest.NAMESPACE}.#{id}"


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
          joined:       Date.create(score)

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
            result.completed = Date.create(score)
            callback null, result

 
module.exports = SplitTest
