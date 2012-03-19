{ setup } = require("./helper")
assert    = require("assert")
Activity  = require("../models/activity")
request   = require("request")


describe "activity", ->
  before setup


  # Getting an activity
  describe "get", ->
    before (done)->
      params =
        id:     "deleteme"
        actor:  { displayName: "Assaf" }
        verb:   "posted"
      Activity.create id: "seeme", actor: { displayName: "Assaf" }, verb: "tested", done

    it "should return 200", (done)->
      request.get "http://localhost:3003/activity/seeme", (_, response)->
        assert.equal response.statusCode, 200
        done()

    it "should return JSON object for activity", (done)->
      headers = { "Accept": "application/json" }
      request.get "http://localhost:3003/activity/seeme", headers: headers, (_, response, body)->
        assert.equal response.statusCode, 200
        assert /application\/json/.test(response.headers['content-type'])
        activity = JSON.parse(body)
        assert.equal activity.actor.displayName, "Assaf"
        done()

    it "should return HTML view of activity for text/html", (done)->
      headers = { "Accept": "text/html" }
      request.get "http://localhost:3003/activity/seeme", headers: headers, (_, response, body)->
        assert.equal response.statusCode, 200
        assert /text\/html/.test(response.headers['content-type'])
        assert /<div/.test(body)
        done()

    it "should return HTML view of activity for */*", (done)->
      headers = { "Accept": "*/*" }
      request.get "http://localhost:3003/activity/seeme", headers: headers, (_, response, body)->
        assert.equal response.statusCode, 200
        assert /text\/html/.test(response.headers['content-type'])
        assert /<div/.test(body)
        done()

    it "should return 404 if activity doesn't exist", (done)->
      request.get "http://localhost:3003/activity/nosuch", (_, response)->
        assert.equal response.statusCode, 404
        assert.equal response.body, "Cannot GET /activity/nosuch"
        done()
  

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
