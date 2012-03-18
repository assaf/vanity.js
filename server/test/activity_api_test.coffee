{ setup } = require("./helper")
assert    = require("assert")
Activity  = require("../models/activity")
request   = require("request")


describe "activity", ->
  before setup

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
