QS       = require("querystring")
Activity = require("../models/activity")
server   = require("../config/server")


# View single activity.
server.get "/activity/:id", (req, res, next)->
  res.render "activity", id: req.params.id

# View the activity stream.
server.get "/activity", (req, res, next)->
  res.render "activities"

