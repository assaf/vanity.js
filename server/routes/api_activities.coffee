QS            = require("querystring")
Express       = require("express")
Activity      = require("../models/activity")
authenticate  = require("../config/authenticate")
logger        = require("../config/logger")
server        = require("../config/server")


# Create a new activity.
server.post "/v1/activity", authenticate, (req, res, next)->
  Activity.create req.body, (error, id)->
    if error
      res.send error.message, 400
    else
      res.send " ", location: "/v1/activity/#{id}", 201


# Retrieve recent activities
server.get "/v1/activity", authenticate, (req, res)->
  params = {}
  # Only add query fields that are present.  We use params object to construct query string for next/prev navigation
  # links, so don't include junk in there.
  params.query = req.query.query if req.query.query
  params.limit = parseInt(req.query.limit, 10) if req.query.limit
  params.offset = parseInt(req.query.offset, 10) if req.query.offset
  params.start = req.query.start if req.query.start
  params.end = req.query.end if req.query.end

  Activity.search params, (error, results)->
    if error
      logger.error error.stack
      res.send "Cannot execute query", 400
      return
     
    result =
      query:      params.query || "*"
      totalItems: results.total
      items:      results.activities.map((a)-> enhance(a))
      url:        "/v1/activity"

    # We don't know what limit was applied, but we do know if there are more results beyond what we got, in which case
    # we include link to the next offset.
    next_offset = (params.offset || 0) + results.limit
    if results.total > next_offset
      next = Object.clone(params)
      next.offset = next_offset
      result.next = "/v1/activity?" + QS.stringify(next)

    # We know if there are more results is we navigate back.  We do our best to guess the limit, and make sure offset is not 0.
    if params.offset > 0
      prev = Object.clone(params)
      prev.offset = Math.max(params.offset - results.limit, 0)
      result.prev = "/v1/activity?" + QS.stringify(prev)

    res.send result, 200


# Server-sent events activity stream.
server.get "/v1/activity/stream", authenticate, (req, res, next)->
  res.writeHead 200,
    "Content-Type":   "text/event-stream; charset=utf-8"
    "Cache-Control":  "no-cache"
    "Connection":     "keep-alive"
  res.write ": after 5 seconds\nretry: 5000\n\n"

  # Send each activity that gets created.
  send = (activity)->
    json = JSON.stringify(enhance(activity))
    res.write "event: activity\nid: #{activity.id}\ndata: #{json}\n\n"
  Activity.addListener "activity", send

  # Stop listener when browser disconnects.
  res.socket.on "close", ->
    Activity.removeListener "activity", send


# Retrieve single activity.
server.get "/v1/activity/:id", authenticate, (req, res, next)->
  Activity.get req.params.id, (error, activity)->
    if error
      next(error)
    else if activity
      res.send enhance(activity), 200
    else
      res.send 404


# Delete activity.
server.del "/v1/activity/:id", authenticate, (req, res, next)->
  Activity.delete req.params.id, (error)->
    if error
      next(error)
    else
      res.send 204


# Adds url and HTML presentation.
enhance = (activity)->
  # URL to activity view
  activity.url = "/activity/#{activity.id}"

  unless Activity.template
    Activity.template = Express.view.compile("_activity.eco", {}, null, root: server.settings.views).fn
  activity.html = Activity.template(activity).replace(/\s+/g, " ").replace(/>\s</g, "><")
  return activity

