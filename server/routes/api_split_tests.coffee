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
# a different alternative, returns the status code 409.
#
# In all cases, returns a JSON document with the following properties:
# alternative - Alternative number
# outcome     - Last outcome recorded
server.put "/v1/split/:test/:id", (req, res, next)->
  { alternative, outcome } = req.body
 
  try
    test = new SplitTest(req.params.test)
    test.addParticipant req.params.id, alternative, (error, result)->
      if error
        next(error)
      else if result.alternative == alternative
        res.send result, 200
      else
        res.send result, 409
  catch error
    res.send error.message, 400
