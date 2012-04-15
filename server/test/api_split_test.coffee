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
  before Helper.setup
  before (done)->
    vanity = new Vanity(host: "localhost:3003")
    split = vanity.split("foo-bar")
    # Record participants
    Async.forEach ["8c0521ee", "c2659ef8", "be8bb5b1", "f3cb65e5", "6d9d70c5"],
      (id, done)->
        split.show id, done
      # Records completion
    , ->
      Async.forEach ["8c0521ee", "f3cb65e5"],
        (id, done)->
          split.completed id, done
      , done


  # -- List tests --

  describe "list tests", ->

    statusCode = null
    tests = null

    before (done)->
      # Collect the results
      request.get base_url, (error, response)->
        { statusCode, body } = response
        tests = JSON.parse(response.body).tests if statusCode == 200
        done()

    it "should return 200", ->
      assert.equal statusCode, 200

    it "should return array of tests", ->
      assert.equal tests.length, 1

    it "should return identifier for each test", ->
      assert.equal tests[0].id, "foo-bar"

    it "should return title for each test", ->
      assert.equal tests[0].title, "Foo Bar"

    it "should return created time for each test", ->
      assert Date.create(tests[0].created) - Date.now() < 1000

    it "should return title for each alternative", ->
      assert.equal tests[0].alternatives[0].title, "A"
      assert.equal tests[0].alternatives[1].title, "B"

    it "should return participants for each alternative", ->
      assert.equal tests[0].alternatives[0].participants, 2
      assert.equal tests[0].alternatives[1].participants, 3

    it "should return completed for each alternative", ->
      assert.equal tests[0].alternatives[0].completed, 0
      assert.equal tests[0].alternatives[1].completed, 2


  # -- Retrieving test --

  describe "get test", ->

    statusCode = null
    test = null

    describe "no such test", ->
      before (done)->
        request.get base_url + "nosuch", (_, response)->
          { statusCode, body } = response
          done()

      it "should return 404", ->
        assert.equal statusCode, 404

 
    describe "existing test", ->

      before (done)->
        # Collect the results
        request.get base_url + "foo-bar", (error, response)->
          { statusCode, body } = response
          test = JSON.parse(response.body) if statusCode == 200
          done()

      it "should return 200", ->
        assert.equal statusCode, 200

      it "should return test identifier", ->
        assert.equal test.id, "foo-bar"

      it "should return test title", ->
        assert.equal test.title, "Foo Bar"

      it "should return test created time", ->
        assert Date.create(test.created) - Date.now() < 1000

      it "should return title for each alternative", ->
        assert.equal test.alternatives[0].title, "A"
        assert.equal test.alternatives[1].title, "B"

      it "should return participants for each alternative", ->
        assert.equal test.alternatives[0].participants, 2
        assert.equal test.alternatives[1].participants, 3

      it "should return completed for each alternative", ->
        assert.equal test.alternatives[0].completed, 0
        assert.equal test.alternatives[1].completed, 2

      it "should return historical data for each alternative", ->
        assert a = test.alternatives[0].data
        assert.equal a.length, 1
        assert.equal a[0].participants, 2, "No participants for foo"
        assert.equal a[0].converted, 0, "No test completed for foo"

        assert b = test.alternatives[1].data
        assert.equal b.length, 1
        assert.equal b[0].participants, 3, "No participatnts for bar"
        assert.equal b[0].converted, 2, "No test completed for bar"


