process.env.NODE_ENV = "test"

Async     = require("async")
Browser   = require("zombie")
Replay    = require("replay")
server    = require("../config/server")
redis     = require("../config/redis")
Activity  = require("../models/activity")


Helper =
  # Call this before running each test.
  setup: (callback)->
    redis.flushdb(callback)

  # Call this once before running all tests.
  once: (callback)->
    Async.parallel [
      (done)->
        server.listen(3003, done)
    ], (error)->
      if error
        throw error
      else
        callback()

  # Call this before each test using ElasticSearch to recreate the index.
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

Browser.site = "localhost:3003"


# To capture and record API calls, run with environment variable RECORD=true
Replay.fixtures = "#{__dirname}/replay"
Replay.networkAccess = false
Replay.localhost "localhost"
Replay.ignore "mt1.googleapis.com"


module.exports = Helper
