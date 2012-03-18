Express   = require("express")
FS        = require("fs")
Activity  = require("../models/activity")


server = Express.createServer()
server.get "/activity/:id", (req, res, next)->
  Activity.get req.params.id, (error, activity)->
    if error
      next(error)
      return
    if activity
      activity.layout = null
      res.render "activity", activity
    else
      res.send 404
server.set "views", "#{__dirname}/../views"
server.set "view engine", "eco"


global.server = server
files = FS.readdirSync("#{__dirname}/../routes")
for file in files
  require("#{__dirname}/../routes/#{file}")
#delete global.server


module.exports = server
