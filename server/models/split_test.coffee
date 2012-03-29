redis = require("../config/redis")


class SplitTest

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
        unless changed
          # Someone beat us to it, start over
          @addParticipant participant, alternative, callback
          return

        # Keep record of wen participant joined
        redis.zadd "#{@_base_key}.joined.#{alternative}", Date.now(), participant, (error)->
          callback error,
            participant:  participant
            alternative:  alternative
    return


  setOutcome: (pid, alternative, outcome, callback)->
    @addParticipant pid, alternative, (error, result)->
      return callback(error) if error
      if outcome == null
        callback result
        return
      if isNaN(outcome)
        outcome = 0

      alternative = result.alternative
      redis.hset "#{@_base_key}.outcomes", pid, outcome, (error)=>
        return callback(error) if error
        result.outcome = outcome
        redis.zadd "#{@_base_key}.completed.#{alternative}", Date.now(), pid, (error)->
          callback error, result


  getParticipant: (pid, callback)->
    redis.hget "#{@_base_key}.participants", pid, (error, alternative)->
      return callback(error) if error
      if alternative == null
        callback()
        return

      redis.zscore "#{@_base_key}.joined.#{alternative}", pid, (error, score)->
        return callback(error) if error
        result =
          participant:  pid
          alternative:  parseInt(alternative)
          joined:       Date.create(score)

        redis.hget "#{@_base_key}.outcomes", pid, (error, outcome)->
          return callback(error) if error
          if outcome == null
            callback(null, result)
            return
          result.outcome = outcome

          redis.zscore "#{@_base_key}.completed.#{alternative}", pid, (error, score)->
            return callback(error) if error
            result.completed = Date.create(score)
            callback null, result

 
module.exports = SplitTest
