process.env.NODE_ENV = "test"

Async     = require("async")
Browser   = require("zombie")
Replay    = require("replay")
server    = require("../config/server")
redis     = require("../config/redis")
Activity  = require("../models/activity")


Helper =
  setup: (callback)->
    Async.parallel [
      (done)->
        redis.flushdb(done)
    , (done)->
        server.listen(3003, done)
    ], (error)->
      if error
        throw error
      else
        callback()

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
