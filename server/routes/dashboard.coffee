QS        = require("querystring")
Activity  = require("../models/activity")
SplitTest = require("../models/split_test")
server    = require("../config/server")


# -- Activity stream --

# View the activity stream.
server.get "/activity", (req, res, next)->
  res.render "activity/stream"

# View the activity stream.
server.get "/activity/search", (req, res, next)->
  res.render "activity/search"


# -- Split tests --

# Show all active split tests
server.get "/split", (req, res, next)->
  SplitTest.list (error, splits)->
    if error
      next(error)
    else
      for split in splits
        split.url = "/split/#{split.id}"
      res.render "split/index", splits: splits

# View the activity stream.
server.get "/split/:id", (req, res, next)->
  SplitTest.load req.params.id, (error, split)->
    if error
      next(error)
    else if split
      res.render "split/show", split
    else
      next()

