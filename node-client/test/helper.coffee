process.env.NODE_ENV = "test"

Replay    = require("replay")
Request   = require("request")
server    = require("../../server/config/server")
search    = require("../../server/config/search")


Helper =
  # Fire up the Web server
  setup: (done)->
    search ->
      server.listen 3003, done

  # Deletes the search index
  teardown: (done)->
    search.teardown done

  # Returns all activities that match the search criteria.  Can also call with just callback.
  search: (query, callback)->
    [query, callback] = [null, query] unless callback
    setTimeout ->
      search (es_search)->
        es_search.refresh ->
          Request.get "http://localhost:3003/v1/activity", (error, response, body)->
            if error
              throw error
            if response.statusCode == 200
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
