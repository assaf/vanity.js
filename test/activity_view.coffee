assert  = require("assert")
Browser = require("zombie")
Poutine = require("poutine")
server  = require("../lib/vanity/dashboard")
Activity = require("../lib/vanity/models/activity")


Browser.site = "localhost:3003"


describe "activity", ->
  browser = new Browser()

  before (done)->
    server.listen 3003, done

  describe "actor name", ->
    before (done)->
      Activity.insert _id: "5678", actor: { displayName: "Assaf" }, ->
        browser.visit "/activity/5678", done
  
    it "should include activity identifier", ->
      assert id = browser.query(".activity").getAttribute("id")
      assert.equal id, "activity-5678"

    it "should show actor name", ->
      assert.equal browser.query(".activity .actor .name").innerHTML, "Assaf"

    it "should not show actor image", ->
      assert !browser.query(".activity .actor img")

    it "should not link to actor", ->
      assert !browser.query(".activity .actor a")

  after ->
    Poutine.connect().driver (error, db)->
      db.dropCollection(Activity.collection_name)
