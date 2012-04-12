logger   = require("../config/logger")
redis    = require("../config/redis")
server   = require("../config/server")
SplitTest = require("../models/split_test")


# Returns information about a split test.
#
# Response JSON document includes the following properties:
# id            - Test identifier
# title         - Human readable title
# created       - Timestamp when test was created
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
#
# The request must specify a single parameter (in any supported media type):
# alternative   - The alternative chosen for this participant, either
#                 0 (A) or 1 (B)
#
# Returns status code 200 and a JSON document with one property:
# alternative   - The alternative decided for this participant
server.post "/v1/split/:test/:participant", (req, res, next)->
  alternative = parseInt(req.body.alternative, 10)
  try
    SplitTest.addParticipant req.params.test, req.params.participant, alternative, (error, result)->
      if error
        next(error)
      else
        res.send result
  catch error
    res.send error.message, 400


# Send this request to indicate participant completed the test.
#
# Returns status code 204 (No content).
server.post "/v1/split/:test/:participant/completed", (req, res, next)->
  try
    SplitTest.completed req.params.test, req.params.participant, (error)->
      if error
        next(error)
      else
        res.send 202
  catch error
    res.send error.message, 404


# Returns the raw data part of this split test.
#
# Response JSON document is an array with one element for each alternative.
# Each element is itself an array with the properties:
# time          - Date/time at 1 hour resoultion (RFC3339)
# participants  - Number of participants joined during that hour
# completed     - How many of these participants completed the test
server.get "/v1/split/:test/data", (req, res, next)->
  SplitTest.data req.params.test, (error, data)->
    if data
      res.send data
    else
      next(error)


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
    SplitTest.getParticipant req.params.test, req.params.participant, (error, result)->
      if result
        res.send result
      else
        next(error)
  catch error
    res.send error.message, 404

