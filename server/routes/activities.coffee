Activity = require("../models/activity")


server.post "/activity", (req, res, next)->
  next()


server.get "/activity", (req, res, next)->
  next()


server.get "/activity/day/:date", (req, res, next)->
  next()


# Retrieve single activity, either as JSON or HTML.
server.get "/activity/:id", (req, res, next)->
  Activity.get req.params.id, (error, activity)->
    if error
      next(error)
    else if activity
      if req.accepts("html")
        activity.layout = null
        res.render "activity", activity
      else
        res.send activity, 200
    else
      next()


server.get "/activity/stream", (req, res, next)->
  next()


# Delete activity.
server.del "/activity/:id", (req, res, next)->
  Activity.delete req.params.id, (error)->
    if error
      next(error)
    else
      res.send 204
