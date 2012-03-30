Helper            = require("./helper") # must be at top
assert            = require("assert")
Async             = require("async")
{ EventEmitter }  = require("events")
request           = require("request")
EventSource       = require("./event_source")
redis             = require("../config/redis")


describe "API split test participants", ->
  base_url = "http://localhost:3003/v1/split/foobar/"

  before Helper.once


  # -- Adding participant --
  
  describe "add participant", ->
    statusCode = body = null

    before Helper.setup
    before (done)->
      request.put base_url + "8fea081c", json: { alternative: 2 }, (_, response)->
        { statusCode, body } = response
        done()

    it "should return 200", ->
      assert.equal statusCode, 200

    it "should return participant identifier", ->
      assert.equal body.participant, "8fea081c"

    it "should return alternative number", ->
      assert.equal body.alternative, 2

    it "should store participant", (done)->
      request.get base_url + "8fea081c", (_, { body })->
        result = JSON.parse(body)
        assert.equal result.participant, "8fea081c"
        assert.equal result.alternative, 2
        assert Date.create(result.joined) - Date.now() < 1000
        done()


  # -- Change alternative --
  
  describe "change participant", ->
    statusCode = body = null

    before Helper.setup
    before (done)->
      request.put base_url + "ad9fe6597", json: { alternative: 2 }, done
    before (done)->
      request.put base_url + "ad9fe6597", json: { alternative: 3 }, (_, response)->
        { statusCode, body } = response
        done()

    it "should return 409", ->
      assert.equal statusCode, 409

    it "should return participant identifier", ->
      assert.equal body.participant, "ad9fe6597"

    it "should return original alternative", ->
      assert.equal body.alternative, 2


  # -- Adding participant and settings outcome --
  
  describe "add participant and set outcome", ->
    statusCode = body = null

    before Helper.setup
    before (done)->
      request.put base_url + "b6f34cba", json: { alternative: 3 }, done
    before (done)->
      request.put base_url + "b6f34cba", json: { alternative: 3, outcome: 5.6 }, (_, response)->
        { statusCode, body } = response
        done()

    it "should return 200", ->
      assert.equal statusCode, 200

    it "should return participant identifier", ->
      assert.equal body.participant, "b6f34cba"

    it "should return alternative number", ->
      assert.equal body.alternative, 3

    it "should return outcome value", ->
      assert.equal body.outcome, 5.6

    it "should store participant", (done)->
      request.get base_url + "b6f34cba", (_, { body })->
        result = JSON.parse(body)
        assert.equal result.participant, "b6f34cba"
        assert.equal result.alternative, 3
        assert Date.create(result.joined) - Date.now() < 1000
        assert.equal result.outcome, 5.6
        assert Date.create(result.completed) - Date.now() < 1000
        done()


  describe "set outcome without adding participant", ->
    statusCode = body = null

    before Helper.setup
    before (done)->
      request.put base_url + "d5df3958", json: { alternative: 1, outcome: 78 }, (_, response)->
        { statusCode, body } = response
        done()

    it "should return 200", ->
      assert.equal statusCode, 200

    it "should return participant identifier", ->
      assert.equal body.participant, "d5df3958"

    it "should return alternative number", ->
      assert.equal body.alternative, 1

    it "should return outcome value", ->
      assert.equal body.outcome, 78

    it "should store participant", (done)->
      request.get base_url + "d5df3958", (_, { body })->
        result = JSON.parse(body)
        assert.equal result.participant, "d5df3958"
        assert.equal result.alternative, 1
        assert Date.create(result.joined) - Date.now() < 1000
        assert.equal result.outcome, 78
        assert Date.create(result.completed) - Date.now() < 1000
        done()


  # -- Error handling --
  
  describe "missing alternative", ->
    statusCode = body = null

    before (done)->
      request.put base_url + "fbb28a111", json: { alternative: "" }, (_, response)->
        { statusCode, body } = response
        done()

    it "should return 400", ->
      assert.equal statusCode, 400

    it "should return error", ->
      assert.equal body, "Missing alternative number"

  describe "alternative is negative", ->
    statusCode = body = null

    before (done)->
      request.put base_url + "b715d1f4e", json: { alternative: -5 }, (_, response)->
        { statusCode, body } = response
        done()

    it "should return 400", ->
      assert.equal statusCode, 400

    it "should return error", ->
      assert.equal body, "Alternative cannot be a negative number"

  describe "alternative is decimal", ->
    statusCode = body = null

    before (done)->
      request.put base_url + "76c18f432", json: { alternative: 1.02 }, (_, response)->
        { statusCode, body } = response
        done()

    it "should return 400", ->
      assert.equal statusCode, 400

    it "should return error", ->
      assert.equal body, "Alternative must be an integer"


  describe "invlid test identifier", ->
    statusCode = body = null

    before (done)->
      url = "http://localhost:3003/v1/split/foo+bar/76c18f432"
      request.put url, json: { alternative: 1 }, (_, response)->
        { statusCode, body } = response
        done()

    it "should return 400", ->
      assert.equal statusCode, 400

    it "should return error", ->
      assert.equal body, "Split test identifier may only contain alphanumeric, underscore and hyphen"


  describe "outcome is NaN", ->
    statusCode = body = null

    before (done)->
      request.put base_url + "43c1c137", json: { alternative: 1, outcome: "NaN" }, (_, response)->
        { statusCode, body } = response
        done()

    it "should return 400", ->
      assert.equal statusCode, 400

    it "should return error", ->
      assert.equal body, "Outcome must be numeric value"
