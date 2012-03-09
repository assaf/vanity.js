Express = require("express")
Activity = require("../models/activity")

server = Express.createServer()
server.get "/activity/:id", (req, res, next)->
  Activity.find req.params.id, (error, activity)->
    return next(error) if error
    if activity
      activity.layout = null
      res.render "activity", activity
    else
      res.send 404
server.set "views", "#{__dirname}/views"
server.set "view engine", "eco"


module.exports = server
