Express   = require("express")
FS        = require("fs")
Activity  = require("../models/activity")


server = Express.createServer()
server.set "views", "#{__dirname}/../views"
server.set "view engine", "eco"
server.use Express.bodyParser()
server.use Express.query()

server.configure "test", ->
  server.error (error, req, res, next)->
    console.error error
    next error

server.configure ->
  FS.readdir "#{__dirname}/../routes", (error, files)->
    for file in files
      require("#{__dirname}/../routes/#{file}")


module.exports = server
