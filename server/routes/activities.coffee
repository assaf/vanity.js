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
  Activity.search "*", (error, result)->
    console.log error if error
    { total, hits } = result
    activities = hits.map((a)-> a._source )
    res.send total: total, activities: activities, 200
  

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
