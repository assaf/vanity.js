process.env.NODE_ENV = "test"

Async       = require("async")
Replay      = require("replay")
Request     = require("request")
server      = require("../../server/config/server")
redis       = require("../../server/config/redis")
Activity    = require("../../server/models/activity")
EventSource = require("../../server/test/event_source")


Helper =
  # Run before each test to clean up
  setup: (callback)->
    redis.keys "#{redis.prefix}.*", (error, keys)->
      if error
        throw error
      if keys.length == 0
        callback()
      else
        redis.del keys..., callback
  
  # Fire up the Web server
  once: (callback)->
    server.listen 3003, (error)->
      if error
        throw error
      else
        callback()

  # Create a new index.  Each test should run with a new index.
  newIndex: (callback)->
    Activity.deleteIndex (error)->
      if error
        throw error
      else
        Activity.createIndex (error)->
          if error
            throw error
          else
            callback()

  # Connects to activity stream and waits for specified number of activities to
  # come through, before passing array of activities to callback.
  waitFor: (count, callback)->
    # Collect activities into this array.
    activities = []
    # Open event source and start listening to events.
    events = new EventSource("http://localhost:3003/v1/activity/stream")
    events.onmessage = (event)->
      activities.push JSON.parse(event.data)
      # If we got as many activities as we need, close this event source and
      # pass them on to callback.
      if activities.length == count
        events.close()
        if callback
          process.nextTick callback.bind(null, activities)
          callback = null
    events.onerror = (event)->
      callback(event.error)
    # Don't wait forever, in fact, some tests wil never collect any activities.
    # When timeout, close the event stream, call callback with empty array.
    setTimeout ->
      events.close()
      if callback
        process.nextTick callback.bind(null, [])
        # Make sure callback is not called twice.
        callback = null
    , 250
    return


# To capture and record API calls, run with environment variable RECORD=true
Replay.fixtures = "#{__dirname}/replay"
Replay.networkAccess = false
Replay.localhost "localhost"
Replay.ignore "mt1.googleapis.com"


module.exports = Helper
