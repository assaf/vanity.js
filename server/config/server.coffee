# App timezone is UTC. This needs to be set before ANY Date() methods are called
# or it will be ignored
process.env.TZ = "UTC"

# NODE_ENV first, do no damage
process.env.NODE_ENV ||= "development"


Express   = require("express")
FS        = require("fs")
logger    = require("./logger")
Activity  = require("../models/activity")


server = Express.createServer()

server.configure "production", ->
  # Cache all static assets
  server.use Express.staticCache()


# All environments have this configuration: static files, views, JSONP, logging.
server.configure ->
  # Root directory.
  server.set "root", __dirname
  # Static assets
  server.use Express.static("#{__dirname}/../public")
  # Views
  server.set "views", "#{__dirname}/../views"
  server.set "view engine", "eco"
  server.enable "json callback"

  # Log all requests, except static content (above)
  server.use (req, res, next)->
    start = Date.now()
    end_fn = res.end
    res.end = ->
      remote_addr = req.socket && (req.socket.remoteAddress || (req.socket.socket && req.socket.socket.remoteAddress))
      referer = req.headers["referer"] || req.headers["referrer"] || ""
      ua = req.headers["user-agent"] || "-"
      length = res._headers["content-length"] || "-"
      logger.info "#{remote_addr} - \"#{req.method} #{req.originalUrl} HTTP/#{req.httpVersionMajor}.#{req.httpVersionMinor}\" #{res.statusCode} #{length} \"#{referer}\" \"#{ua}\" - #{Date.now() - start} ms"
      res.end = end_fn
      end_fn.apply(res, arguments)
    next()
  

# Error handling for production
server.configure "production", ->
  server.use (error, req, res, next)->
    logger.error error.stack
    next error

# Error handling and profiling in development
server.configure "development", ->
  server.use Express.profiler()
  server.use Express.errorHandler(showStack: true)

# Error handling in test mode.  Remember to look in logs/test.log!
#
# Without seeing errors somewhere (log file), it's impossible to debug test
# errors.
server.configure "test", ->
  server.error (error, req, res, next)->
    console.error error.stack
    next error


# Query and body parsing and routes.  These are also common in all environments.
server.configure ->
  # Body and query parameters
  server.use Express.bodyParser()
  server.use Express.query()

  # Load all routes
  FS.readdir "#{__dirname}/../routes", (error, files)->
    for file in files
      require("#{__dirname}/../routes/#{file}")


# Create ElasticSearch index if necessary.
Activity.createIndex (error)->
  if error
    throw error


module.exports = server
