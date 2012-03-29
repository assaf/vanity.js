redis = require("../config/redis")


class SplitTest
  @NAMESPACE = "vanity.split"

  constructor: (@id)->
    @base_key = "#{SplitTest.NAMESPACE}.#{@id}"


  addParticipant: (pid, alternative, callback)->
    pid = pid.toString() unless Object.isString(pid)
    alternative = Math.floor(alternative)
    if isNaN(alternative)
      process.nextTick ->
        callback new Error("Alternative must be a number")
      return

    # First check if we already know which alternative was presented.
    redis.hget "#{@base_key}.participants", pid, (error, known)=>
      return callback(error) if error
      if known != null
        # Respond with identifier and alternative
        callback error,
          participant:  pid
          alternative:  parseInt(known)
        return

      # Set the alternative if not already set (avoid race condition).
      redis.hsetnx "#{@base_key}.participants", pid, alternative, (error, changed)=>
        return callback(error) if error
        unless changed
          # Someone beat us to it, start over
          @addParticipant pid, alternative, callback
          return

        # Keep record of wen participant joined
        redis.zadd "#{@base_key}.alternatives.#{alternative}", Date.now(), pid, (error)->
          return callback(error) if error
          callback error,
            participant:  pid
            alternative:  alternative


  getParticipant: (pid, callback)->
    redis.hget "#{@base_key}.participants", pid, (error, alternative)->
      if error
        callback(error)
        return
      if alternative == undefined
        callback(null)
        return

      redis.zscore "#{@base_key}.alternatives.#{alternative}", pid, (error, score)->
        if error
          callback(error)
          return

        joined = Date.create(score)
        callback null,
          participant:  pid
          alternative:  parseInt(alternative)
          joined:       Date.create(joined)

 
module.exports = SplitTest
