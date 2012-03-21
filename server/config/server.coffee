process.env.NODE_ENV ||= "development"
Express   = require("express")
FS        = require("fs")


server = Express.createServer()

server.configure "production", ->
  # Cache all static assets
  server.use Express.staticCache()

server.configure ->
  # Static assets
  server.use Express.static("#{__dirname}/../public")
  # Views
  server.set "views", "#{__dirname}/../views"
  server.set "view engine", "eco"
  # Body and query parameters
  server.use Express.bodyParser()
  server.use Express.query()

server.configure "production", ->
  server.use Express.logger()

server.configure "development", ->
  server.use Express.logger()

server.configure "test", ->
  server.error (error, req, res, next)->
    console.error error
    next error

# Load all routes
server.configure ->
  FS.readdir "#{__dirname}/../routes", (error, files)->
    for file in files
      require("#{__dirname}/../routes/#{file}")


module.exports = server
