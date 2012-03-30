Helper            = require("./helper") # must be at top
assert            = require("assert")
Async             = require("async")
{ EventEmitter }  = require("events")
request           = require("request")
EventSource       = require("./event_source")
redis             = require("../config/redis")


describe "API split test", ->

  base_url = "http://localhost:3003/v1/split/"

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
      test = null

      before Helper.setup
      before (done)->
        params =
          title: "Foo vs Bar"
        request.put test_url, json: params, done
      before (done)->
        request.get test_url, (_, response)->
          { statusCode } = response
          test = JSON.parse(response.body)
          done()

      it "should return 200", ->
        assert.equal statusCode, 200

      it "should return title", ->
        assert.equal test.title, "Foo vs Bar"

      it "should return created time", ->
        assert Date.create(test.created) - Date.now() < 1000


    describe "some participants", ->

      test_url = base_url + "virgin"
      test = null

      before Helper.setup
      before (done)->
        params =
          title: "Foo vs Bar"
        request.put test_url, json: params, done
      before (done)->
        request.get test_url, (_, response)->
          { statusCode } = response
          test = JSON.parse(response.body)
          done()

      it "should return 200", ->
        assert.equal statusCode, 200

      it "should return title", ->
        assert.equal test.title, "Foo vs Bar"

      it "should return created time", ->
        assert Date.create(test.created) - Date.now() < 1000

