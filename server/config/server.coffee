process.env.NODE_ENV ||= "development"
Express   = require("express")
FS        = require("fs")
logger    = require("./logger")


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

  # Log all requests, except static content (above)
  server.use (req, res, next)->
    start = Date.now()
    end_fn = res.end
    res.end = ->
      remote_addr = req.socket && (req.socket.remoteAddress || (req.socket.socket && req.socket.socket.remoteAddress))
      referer = req.headers["referer"] || req.headers["referrer"] || ""
      length = res._headers["content-length"] || "-"
      logger.info "#{remote_addr} - \"#{req.method} #{req.originalUrl} HTTP/#{req.httpVersionMajor}.#{req.httpVersionMinor}\" #{res.statusCode} #{length} \"#{referer}\" \"#{req.headers["user-agent"]}\" - #{Date.now() - start} ms"
      res.end = end_fn
      end_fn.apply(res, arguments)
    next()
  

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
