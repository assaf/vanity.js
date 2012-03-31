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

      it "should return alterantives", ->
        assert.equal test.alternatives.length, 2
        assert.equal test.alternatives[0].title, "A"
        assert.equal test.alternatives[1].title, "B"

      it "should return alterantives of equal weight", ->
        assert.equal test.alternatives.length, 2
        assert.equal test.alternatives[0].weight, 0.5
        assert.equal test.alternatives[1].weight, 0.5


    describe "some participants", ->

      test_url = base_url + "foo-bar"
      test = null

      before Helper.setup
      before (done)->
        vanity = new Vanity(host: "localhost:3003")
        split = vanity.split("foo-bar")
        params =
          title:        "Foo vs Bar"
          alternatives: ["foo", "bar"]
        request.put test_url, json: params, ->
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

      it "should return participant counts", ->
        foo = test.alternatives[0].participants
        assert.equal foo[0].count, 2
        bar = test.alternatives[1].participants
        assert.equal bar[0].count, 3

      it "should return completion counts", ->
        foo = test.alternatives[0].completions
        assert.equal foo.length, 0
        bar = test.alternatives[1].completions
        assert.equal bar[0].count, 2

