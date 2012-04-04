QS        = require("querystring")
Activity  = require("../models/activity")
SplitTest = require("../models/split_test")
server    = require("../config/server")


# View the activity stream.
server.get "/activity", (req, res, next)->
  res.render "activity/stream"

# View the activity stream.
server.get "/activity/search", (req, res, next)->
  res.render "activity/search"


# View the activity stream.
server.get "/split/:id", (req, res, next)->
  SplitTest.load req.params.id, (error, test)->
    if error
      next(error)
    else if test
      res.render "split/show", test
    else
      next()
