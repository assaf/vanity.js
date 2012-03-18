Activity = require("../models/activity")


server.post "/activity", (req, res, next)->
  next()


server.get "/activity", (req, res, next)->
  next()


server.get "/activity/day/:date", (req, res, next)->
  next()


server.get "/activity/:id", (req, res, next)->
  next()


server.get "/activity/stream", (req, res, next)->
  next()


server.del "/activity/:id", (req, res, next)->
  Activity.delete req.params.id, (error)->
    if error
      next(error)
    else
      res.send 204
