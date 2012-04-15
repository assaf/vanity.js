logger   = require("../config/logger")
redis    = require("../config/redis")
server   = require("../config/server")
SplitTest = require("../models/split_test")


# Returns a list of all active split test.
server.get "/v1/split", (req, res, next)->
  SplitTest.list (error, tests)->
    if tests
      res.send tests: tests
    else
      next(error)

# Returns information about a split test.
server.get "/v1/split/:test", (req, res, next)->
  SplitTest.load req.params.test, (error, test)->
    if test
      res.send
        id:           test.id
        title:        test.title
        created:      test.created
        alternatives: test.alternatives
    else
      next(error)

# Send this request to indicate participant joined the test.
server.post "/v1/split/:test/:participant", (req, res, next)->
  alternative = parseInt(req.body.alternative, 10)
  try
    SplitTest.participated req.params.test, req.params.participant, alternative, (error, result)->
      if error
        next(error)
      else
        res.send result
  catch error
    res.send error.message, 400

# Send this request to indicate participant completed the test.
server.post "/v1/split/:test/:participant/completed", (req, res, next)->
  try
    SplitTest.completed req.params.test, req.params.participant, (error)->
      if error
        next(error)
      else
        res.send 202
  catch error
    res.send error.message, 404

# Returns information about participant.
server.get "/v1/split/:test/:participant", (req, res, next)->
  SplitTest.getParticipant req.params.test, req.params.participant, (error, result)->
    if result
      res.send result
    else
      next(error)

