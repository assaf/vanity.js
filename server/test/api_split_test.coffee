Helper            = require("./helper") # must be at top
assert            = require("assert")
Async             = require("async")
{ EventEmitter }  = require("events")
request           = require("request")
EventSource       = require("./event_source")
redis             = require("../config/redis")


describe "API split", ->
  url = "http://localhost:3003/v1/split/foobar/8fea081c"
  base_url = "http://localhost:3003/v1/split/foobar/8fea081c"

  before Helper.setup


  # -- Adding participant --
  
  describe "add participant", ->
    statusCode = body = headers = null

    before (done)->
      request.put url, json: { alternative: 2 }, (_, response)->
        { statusCode, headers, body } = response
        done()

    it "should return 200", ->
      assert.equal statusCode, 200

    it "should return participant identifier", ->
      assert.equal body.participant, "8fea081c"

    it "should return alternative number", ->
      assert.equal body.alternative, 2


  # -- Change alternative --
  
  describe "change participant", ->
    statusCode = body = headers = null

    before (done)->
      request.put url, json: { alternative: 2 }, (_, response)->
        request.put url, json: { alternative: 3 }, (_, response)->
          { statusCode, headers, body } = response
          done()

    it "should return 409", ->
      assert.equal statusCode, 409

    it "should return participant identifier", ->
      assert.equal body.participant, "8fea081c"

    it "should return original alternative", ->
      assert.equal body.alternative, 2


