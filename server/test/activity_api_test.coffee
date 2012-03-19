assert    = require("assert")
Async     = require("async")
request   = require("request")
Activity  = require("../models/activity")
search    = require("../config/search")
{ setup } = require("./helper")


describe "activity", ->
  before setup


  # Creating an activity
  describe "post", ->
    statusCode = body = headers = null
    params =
      id:     "posted"
      actor:  { displayName: "Assaf" }
      verb:   "posted"

    describe "valid", ->
      before (done)->
        request.post "http://localhost:3003/activity", json: params, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should create activity", (done)->
        setTimeout ->
          Activity.get "posted", (error, activity)->
            assert activity
            assert.equal activity.actor.displayName, "Assaf"
            done()
        , 100

      it "should return 201", ->
        assert.equal statusCode, 201

      it "should return location of new activity", ->
        assert.equal headers["location"], "/activity/posted"

      it "should return empty document", ->
        assert.equal body, " "

    describe "not valid", ->
      before (done)->
        request.post "http://localhost:3003/activity", json: { }, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return 400", ->
        assert.equal statusCode, 400

      it "should return error message", ->
        assert.equal body, "Activity requires verb"

    describe "no body", ->
      before (done)->
        request.post "http://localhost:3003/activity", (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return 400", ->
        assert.equal statusCode, 400

      it "should return error message", ->
        assert.equal body, "Activity requires verb"

    after search.teardown


  # Listing all activities
  describe "list activities", ->
    statusCode = body = headers = null

    before (done)->
      file = require("fs").readFileSync("#{__dirname}/fixtures/activities.json")
      Async.forEach JSON.parse(file), (activity, done)->
        Activity.create activity, done
      , ->
        search (es_index)->
          es_index.refresh done
        

    describe "JSON", (done)->
      before (done)->
        headers = { "Accept": "application/json" }
        request.get "http://localhost:3003/activity", headers: headers, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return 200", ->
        assert.equal statusCode, 200

      it "should return a JSON document", ->
        assert /application\/json/.test(headers['content-type'])

      it "should return results count", ->
        { total } = JSON.parse(body)
        assert.equal total, 3

      it "should return activities", ->
        { activities } = JSON.parse(body)
        for activity in activities
          assert activity.actor?.displayName

      it "should return most recent activity first", ->
        { activities } = JSON.parse(body)
        ids = activities.map((a)-> a.id)
        assert.deepEqual ids, ["3", "2", "1"]

    after search.teardown


  # Getting an activity
  describe "get activity", ->
    statusCode = body = headers = null

    before (done)->
      params =
        id:     "seeme"
        actor:  { displayName: "Assaf" }
        verb:   "posted"
      Activity.create id: "seeme", actor: { displayName: "Assaf" }, verb: "tested", done

    describe "JSON", (done)->
      before (done)->
        headers = { "Accept": "application/json" }
        request.get "http://localhost:3003/activity/seeme", headers: headers, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return 200", ->
        assert.equal statusCode, 200

      it "should return a JSON document", ->
        assert /application\/json/.test(headers['content-type'])

      it "should return the activity", ->
        activity = JSON.parse(body)
        assert.equal activity.id, "seeme"
        assert.equal activity.actor.displayName, "Assaf"

    describe "HTML", (done)->
      before (done)->
        headers = { "Accept": "text/html" }
        request.get "http://localhost:3003/activity/seeme", headers: headers, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return 200", ->
        assert.equal statusCode, 200

      it "should return an HTML document", ->
        assert /text\/html/.test(headers['content-type'])
        assert /<div/.test(body)

    describe "any content type", (done)->
      before (done)->
        headers = { "Accept": "*/*" }
        request.get "http://localhost:3003/activity/seeme", headers: headers, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return 200", ->
        assert.equal statusCode, 200

      it "should return an HTML document", ->
        assert /text\/html/.test(headers['content-type'])
        assert /<div/.test(body)

    describe "no such activity", (done)->
      before (done)->
        headers = { "Accept": "*/*" }
        request.get "http://localhost:3003/activity/nosuch", headers: headers, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return 404", ->
        assert.equal statusCode, 404

      it "should return an error message", ->
        assert.equal body, "Cannot GET /activity/nosuch"

    after search.teardown
  

  # Deleting an activity
  describe "delete", ->
    before (done)->
      params =
        id:     "deleteme"
        actor:  { displayName: "Assaf" }
        verb:   "posted"
      Activity.create id: "deleteme", actor: { displayName: "Assaf" }, verb: "tested", ->
        Activity.create id: "keepme", actor: { displayName: "Assaf" }, verb: "tested", done

    it "should delete activity", (done)->
      request.del "http://localhost:3003/activity/deleteme", ->
        Activity.get "deleteme", (error, doc)->
          assert !error && !doc
          done()

    it "should return 204", (done)->
      request.del "http://localhost:3003/activity/deleteme", (_, response)->
        assert.equal response.statusCode, 204
        done()

    it "should not fail if no such activity", (done)->
      request.del "http://localhost:3003/activity/nosuch", (error, response)->
        assert.equal response.statusCode, 204
        done()

    it "should not delete unrelated activity", (done)->
      Activity.get "keepme", (error, doc)->
        assert doc && doc.actor
        done()

    after search.teardown


