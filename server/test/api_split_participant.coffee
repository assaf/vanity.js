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
      request.post base_url + "8fea081c?access_token=secret", json: { alternative: 1 }, (_, response)->
        { statusCode, body } = response
        console.log body
        done()

    it "should return 200", ->
      assert.equal statusCode, 200

    it "should return participant identifier", ->
      assert.equal body.participant, "8fea081c"

    it "should return alternative number", ->
      assert.equal body.alternative, 1

    it "should store participant", (done)->
      request.get base_url + "8fea081c?access_token=secret", (_, { body })->
        result = JSON.parse(body)
        assert.equal result.participant, "8fea081c"
        assert.equal result.alternative, 1
        assert Date.create(result.joined) - Date.now() < 1000
        assert !result.completed
        done()


  # -- Change alternative --
  
  describe "change participant", ->
    statusCode = body = null

    before Helper.setup
    before (done)->
      request.post base_url + "ad9fe6597?access_token=secret", json: { alternative: 1 }, done
    before (done)->
      request.post base_url + "ad9fe6597?access_token=secret", json: { alternative: 0 }, (_, response)->
        { statusCode, body } = response
        done()

    it "should return 200", ->
      assert.equal statusCode, 200

    it "should return participant identifier", ->
      assert.equal body.participant, "ad9fe6597"

    it "should return original alternative", ->
      assert.equal body.alternative, 1


  # -- Adding participant and settings outcome --
  
  describe "add participant and complete", ->
    statusCode = body = null

    before Helper.setup
    before (done)->
      request.post base_url + "b6f34cba?access_token=secret", json: { alternative: 1 }, done
    before (done)->
      request.post base_url + "b6f34cba/completed?access_token=secret", (_, response)->
        { statusCode, body } = response
        done()

    it "should return 200", ->
      assert.equal statusCode, 202

    it "should update participant", (done)->
      request.get base_url + "b6f34cba?access_token=secret", (_, { body })->
        result = JSON.parse(body)
        assert.equal result.participant, "b6f34cba"
        assert.equal result.alternative, 1
        assert Date.create(result.joined) - Date.now() < 1000
        assert Date.create(result.completed) - Date.now() < 1000
        done()


  describe "complete without adding participant", ->
    statusCode = body = null

    before Helper.setup
    before (done)->
      request.post base_url + "d5df3958/completed?access_token=secret", (_, response)->
        { statusCode } = response
        done()

    it "should return 202", ->
      assert.equal statusCode, 202

    it "should not store participant", (done)->
      request.get base_url + "d5df3958?access_token=secret", (_, { statusCode })->
        assert.equal statusCode, 404
        done()


  # -- Error handling --
  
  describe "missing alternative", ->
    statusCode = body = null

    before (done)->
      request.post base_url + "fbb28a111?access_token=secret", json: { alternative: "" }, (_, response)->
        { statusCode, body } = response
        done()

    it "should return 200", ->
      assert.equal statusCode, 200

    it "should assume false", (done)->
      request.get base_url + "fbb28a111?access_token=secret", (_, { body })->
        result = JSON.parse(body)
        assert.equal result.alternative, 0
        done()


  describe "alternative is negative", ->
    statusCode = body = null

    before (done)->
      request.post base_url + "b715d1f4e?access_token=secret", json: { alternative: -5 }, (_, response)->
        { statusCode, body } = response
        done()

    it "should return 200", ->
      assert.equal statusCode, 200

    it "should assume true", (done)->
      request.get base_url + "b715d1f4e?access_token=secret", (_, { body })->
        result = JSON.parse(body)
        assert.equal result.alternative, 1
        done()
        

  describe "alternative is decimal", ->
    statusCode = body = null

    before (done)->
      request.post base_url + "76c18f432?access_token=secret", json: { alternative: 1.02 }, (_, response)->
        { statusCode, body } = response
        done()

    it "should return 200", ->
      assert.equal statusCode, 200

    it "should assume true", (done)->
      request.get base_url + "76c18f432?access_token=secret", (_, { body })->
        result = JSON.parse(body)
        assert.equal result.alternative, 1
        done()


  describe "invlid test identifier", ->
    statusCode = body = null

    before (done)->
      url = "http://localhost:3003/v1/split/foo+bar/76c18f432?access_token=secret"
      request.post url, json: { alternative: 1 }, (_, response)->
        { statusCode, body } = response
        done()

    it "should return 400", ->
      assert.equal statusCode, 400

    it "should return error", ->
      assert.equal body, "Split test identifier may only contain alphanumeric, underscore and hyphen"
