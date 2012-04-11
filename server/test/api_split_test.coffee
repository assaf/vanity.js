Helper            = require("./helper") # must be at top
assert            = require("assert")
Async             = require("async")
{ EventEmitter }  = require("events")
request           = require("request")
EventSource       = require("./event_source")
redis             = require("../config/redis")
Vanity            = require("../../node/vanity")


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


    describe "some participants", ->

      test_url = base_url + "foobar1"
      test = null

      before Helper.setup
      before (done)->
        vanity = new Vanity(host: "localhost:3003")
        split = vanity.split("foobar1")
        # Record participants
        Async.forEach ["8c0521ee", "c2659ef8", "be8bb5b1", "f3cb65e5", "6d9d70c5"],
          (id, done)->
            split.show id, done
        , done
      before (done)->
        # Collect the results
        request.get test_url, (error, response)->
          { statusCode, body } = response
          test = JSON.parse(response.body) if statusCode == 200
          done()

      it "should return 200", ->
        assert.equal statusCode, 200

      it "should return created time", ->
        assert Date.create(test.created) - Date.now() < 1000



  # -- Test data --

  describe "data", ->

    test_url = base_url + "foobar2"
    split = null
    result = statusCode = null

    before Helper.setup
    before (done)->
      vanity = new Vanity(host: "localhost:3003")
      split = vanity.split("foobar2")
      process.nextTick done
    before (done)->
      # Record participants
      Async.forEach ["8c0521ee", "c2659ef8", "be8bb5b1", "f3cb65e5", "6d9d70c5"],
        (id, done)->
          split.show id, done
      , (callback)->
        # Records completion
        Async.forEach ["8c0521ee", "f3cb65e5"],
          (id, done)->
            split.completed id, done
        , done
    before (done)->
      # Collect the results
      request.get test_url + "/data", (_, response)->
        { statusCode, body } = response
        result = JSON.parse(response.body) if statusCode == 200
        done()

    it "should return 200", ->
      assert.equal statusCode, 200

    it "should return historical data for each alternative", ->
      assert foo = result[0]
      assert.equal foo.length, 1
      assert.equal foo[0].participants, 2, "No participants for foo"
      assert.equal foo[0].converted, 0, "No test completed for foo"

      assert bar = result[1]
      assert.equal bar.length, 1
      assert.equal bar[0].participants, 3, "No participatnts for bar"
      assert.equal bar[0].converted, 2, "No test completed for bar"
