QS       = require("querystring")
Activity = require("../models/activity")
server   = require("../config/server")


# View the activity stream.
server.get "/activity", (req, res, next)->
  res.render "activity/stream"

# View the activity stream.
server.get "/activity/search", (req, res, next)->
  res.render "activity/search"

