Helper            = require("./helper") # must be at top
assert            = require("assert")
Async             = require("async")
{ EventEmitter }  = require("events")
request           = require("request")
EventSource       = require("./event_source")


describe "API split", ->
  before Helper.setup


  # -- Adding participant --
  
  describe "add participant", ->
    statusCode = body = headers = null

    before (done)->
      params =
        alternative: 2
      request.post "http://localhost:3003/v1/split/foobar/8fea081c", json: params, (_, response)->
        { statusCode, headers, body } = response
        done()

    it "should return 200", ->
      assert.equal statusCode, 200

    it "should return participant identifier", ->
      assert.equal body.id, "8fea081c"

    it "should return test identifier", ->
      assert.equal body.test, "foobar"

    it "should return alternative number", ->
      assert.equal body.alternative, 2

    it "should return joined timestamp", ->
      joined = Date.create(body.joined)
      assert.equal joined - Date.now() < 1000


