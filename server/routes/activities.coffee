QS       = require("querystring")
Express  = require("express")
Activity = require("../models/activity")
server   = require("../config/server")


# Create a new activity.
#
# If request is a valid activity, returns 201 and Location header.
#
# Otherwise, returns 400 and error message.
#
# Does not wait for activity to be indexed.
server.post "/activity", (req, res, next)->
  try
    id = Activity.create(req.body, (error)->
      # TODO: proper logging
      if error
        console.log error
    )
    res.send " ", location: "/activity/#{id}", 201
  catch error
    res.send error.message, 400


# Retrieve recent activities
#
# Supports the following query parameters:
# query   - Query string
# limit   - How many results to return (up to 250)
# offset  - Start at this offset (default to 0)
# start   - Returns activities published at/after this time (ISO8601)
# end     - Returns activities published up (excluding) this time (ISO8601)
#
# Returns a JSON document with the following properties:
# totalItems - Total number of activities that match this query
# items      - Activities that match this query (from offset, up to limit)
# url        - URL to the full collection
# next       - Path for requesting the next result set (if not last)
# prev       - Path for requesting the previous result set (if not first
server.get "/activity", (req, res)->
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
      console.error error
      res.send "Cannot execute query", 400
      return
     
    result =
      query:      params.query || "*"
      totalItems: results.total
      items:      results.activities.map((a)-> enhance(a))
      url:        "/activity"

    # We don't know what limit was applied, but we do know if there are more results beyond what we got, in which case
    # we include link to the next offset.
    next_offset = (params.offset || 0) + results.limit
    if results.total > next_offset
      next = Object.clone(params)
      next.offset = next_offset
      result.next = "/activity?" + QS.stringify(next)

    # We know if there are more results is we navigate back.  We do our best to guess the limit, and make sure offset is not 0.
    if params.offset > 0
      prev = Object.clone(params)
      prev.offset = Math.max(params.offset - results.limit, 0)
      result.prev = "/activity?" + QS.stringify(prev)

    if req.accepts("html")
      res.render "activities", result
    else
      res.send result, 200
  

# Server-sent events activity stream.
server.get "/activity/stream", (req, res, next)->
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


server.get "/activity/frequency", (req, res, next)->
  Activity.frequency req.query.params, (error, results)->
    res.send results


# Retrieve single activity, either as JSON or HTML.
server.get "/activity/:id", (req, res, next)->
  Activity.get req.params.id, (error, activity)->
    if error
      next(error)
    else if activity
      if req.accepts("html")
        res.local "layout", (req.headers["x-requested-with"] != "XMLHttpRequest")
        res.local "title", activity.title
        res.render "activity", enhance(activity)
      else
        res.send enhance(activity), 200
    else
      next()


# Delete activity.
server.del "/activity/:id", (req, res, next)->
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

