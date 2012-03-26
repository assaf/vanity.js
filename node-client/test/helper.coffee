process.env.NODE_ENV = "test"

Asynch    = require("async")
Replay    = require("replay")
Request   = require("request")
server    = require("../../server/config/server")
Activity  = require("../../server/models/activity")


Helper =
  # Fire up the Web server
  setup: (callback)->
    server.listen 3003, (error)->
      if error
        throw error
      else
        callback()

  newIndex: (callback)->
    # Start out by deleting any index from previous run
    Activity.deleteIndex (error)->
      if error
        throw error
      else
        Activity.createIndex (error)->
          if error
            throw error
          else
            callback()

  # Returns all activities that match the search criteria.  Can also call with just callback.
  search: (query, callback)->
    [query, callback] = [null, query] unless callback
    # Give ElasticSearch some time to sort itself before proceeding
    setTimeout ->
      Activity.index().refresh ->
        Request.get "http://localhost:3003/v1/activity", (error, response, body)->
          if error
            throw error
          else if response.statusCode == 200
            callback JSON.parse(body).items
          else
            throw new Error("Activity API returned #{response.statusCode}")
    , 100


# To capture and record API calls, run with environment variable RECORD=true
Replay.fixtures = "#{__dirname}/replay"
Replay.networkAccess = false
Replay.localhost "localhost"
Replay.ignore "mt1.googleapis.com"


module.exports = Helper
