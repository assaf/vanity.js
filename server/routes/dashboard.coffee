QS          = require("querystring")
Activity    = require("../models/activity")
SplitTest   = require("../models/split_test")
server      = require("../config/server")


# Middleware that requires used to be authenticated and authorized.
login = (req, res, next)->
  if res.local("user") 
    next()
  else
    res.cookies.set "return_to", req.url
    res.redirect "/authenticate"


# -- Activity stream --

# View the activity stream.
server.get "/activity", login, (req, res, next)->
  res.render "activity/stream"

# View the activity stream.
server.get "/activity/search", login, (req, res, next)->
  res.render "activity/search"


# -- Split tests --

# Show all active split tests
server.get "/split", login, (req, res, next)->
  SplitTest.list (error, splits)->
    if error
      next(error)
    else
      for split in splits
        split.url = "/split/#{split.id}"
      res.render "split/index", splits: splits

# View the activity stream.
server.get "/split/:id", login, (req, res, next)->
  SplitTest.load req.params.id, (error, split)->
    if error
      next(error)
    else if split
      res.render "split/show", split
    else
      next()

