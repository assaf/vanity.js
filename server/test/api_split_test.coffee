Helper            = require("./helper") # must be at top
assert            = require("assert")
Async             = require("async")
{ EventEmitter }  = require("events")
request           = require("request")
EventSource       = require("./event_source")
redis             = require("../config/redis")


describe "API split test", ->

  base_url = "http://localhost:3003/v1/split/"
  test =
    title: "Foo vs Bar"

  before Helper.once


  # -- Retrieving test --
  
  describe "get test", ->
    statusCode = body = null

    describe "no such test", ->
      before Helper.setup
      before (done)->
        request.get base_url + "nosuch", (_, response)->
          { statusCode, body } = response
          done()

      it "should return 404", ->
        assert.equal statusCode, 404


    describe "no participants", ->
      test_url = base_url + "virgin"

      before Helper.setup
      before (done)->
        request.put test_url, json: test, done
      before (done)->
        request.get test_url, (_, response)->
          { statusCode, body } = response
          done()

      it "should return 200", ->
        assert.equal statusCode, 200

