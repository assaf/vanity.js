QS       = require("querystring")
Activity = require("../models/activity")


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


server.get "/activity", (req, res, next)->
  params =
    query:  req.query.query
    limit:  parseInt(req.query.limit, 10) || 50
    offset: parseInt(req.query.offset, 10) || 0
  Activity.search params, (error, result)->
    console.log error if error
    { total, hits } = result
    activities = hits.map((a)-> a._source )
    result =
      total: total
      activities: activities
    if total > params.limit + params.offset
      next = Object.clone(params)
      next.offset = params.offset + params.limit
      result.next = "/activity?" + QS.stringify(next)
    if params.offset > 0
      prev = Object.clone(params)
      prev.offset = Math.max(params.offset - params.limit, 0)
      result.prev = "/activity?" + QS.stringify(prev)
    res.send result, 200
  

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
