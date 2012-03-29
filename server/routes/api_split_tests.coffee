logger   = require("../config/logger")
redis    = require("../config/redis")
server   = require("../config/server")
SplitTest = require("../models/split_test")


# Add participant or record outcome.
#
# Path includes test and participant identifier.
#
# Request is a JSON document with the following properties:
# alternative - Alternative number (0 ... n)
# outcome     - A number
#
# With only alternative, adds participant to split test.
#
# With alternative and outcome, records conversion with the specified value.
#
# If successful, returns the status code 200.  If participant already added with
# a different alternative, returns the status code 409.  For invalid outputs,
# returns status code 400.
#
# In all cases, returns a JSON document with the following properties:
# alternative - Alternative number
# outcome     - Recorded outcome
server.put "/v1/split/:test/:participant", (req, res, next)->
  { alternative, outcome } = req.body
  try
    test = new SplitTest(req.params.test)
    test.setOutcome req.params.participant, alternative, outcome, (error, result)->
      if error
        next(error)
      else if result.alternative == alternative
        res.send result, 200
      else
        res.send result, 409
  catch error
    res.send error.message, 400


# Returns information about participant.
#
# Path includes test and participant identifier.
#
# Response JSON document includes the following properties:
# participant - Identifier
# joined      - Timestamp when participant joined experiment
# alternative - Alternative number
# completed   - Timestamp when participant completed experiment
# outcome     - Recorded outcome
server.get "/v1/split/:test/:participant", (req, res, next)->
  try
    test = new SplitTest(req.params.test)
    test.getParticipant req.params.participant, (error, result)->
      if error
        next(error)
      else if result
        res.send result
      else
        res.send 404
  catch error
    res.send error.message, 404
