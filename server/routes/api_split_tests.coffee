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
# alternatives  - Information about each alternative
#
# Each alternative includes the following properties:
# title         - Human readable title
# weight        - Value between 0 and 1
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


# Creates or updates a split test.
#
# Request JSON document supports the following properties:
# title         - Human readable title
# alternatives  - Information about each alternative
#
# For each alternative you can specify:
# title         - Human readable title
# weight        - Value between 0 and 1
#
# For response JSON document, see GET method.
server.put "/v1/split/:test", (req, res, next)->
  try
    { title, alternatives } = req.body
    test = new SplitTest(req.params.test)
    test.update req.body, (error)->
      if error
        next(error)
      else
        res.send
          id:           test.id
          title:        test.title
          created:      test.created
          alternatives: test.alternatives
  catch error
    res.send error.message, 400


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
      if result
        if result.alternative == alternative
          res.send result, 200
        else
          res.send result, 409
      else
        next(error)
  catch error
    res.send error.message, 400


# Returns the raw data part of this split test.
#
# Response JSON document is an array with one element for each alternative,
# with the properties:
# title         - Human readable title
# weight        - Value between 0 and 1
# data          - Array of historical values
#
# Each entry of the data array has the properties:
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
    test = new SplitTest(req.params.test)
    test.getParticipant req.params.participant, (error, result)->
      if result
        res.send result
      else
        next(error)
  catch error
    res.send error.message, 404

