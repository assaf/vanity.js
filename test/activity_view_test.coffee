process.env.NODE_ENV = "test"
assert    = require("assert")
Browser   = require("zombie")
server    = require("../lib/vanity/dashboard")
Activity  = require("../lib/vanity/models/activity")
Search    = require("../lib/vanity/search")


Browser.site = "localhost:3003"


describe "activity", ->
  browser = new Browser()
  activity_id = null

  before (done)->
    server.listen 3003, ->
      Search.initialize done


  # Activity actor.
  describe "actor", ->

    describe "name only", ->
      before (done)->
        Activity.create actor: { displayName: "Assaf" }, verb: "posted", (error, doc)->
          activity_id = doc.id
          browser.visit "/activity/#{activity_id}", done
    
      it "should include activity identifier", ->
        assert id = browser.query(".activity").getAttribute("id")
        assert.equal id, "activity-#{activity_id}"

      it "should show actor name", ->
        assert.equal browser.query(".activity .actor .name").innerHTML, "Assaf"

      it "should not show actor image", ->
        assert !browser.query(".activity .actor img")

      it "should not link to actor", ->
        assert !browser.query(".activity .actor a")


    describe "no name but id", ->

      before (done)->
        Activity.create actor: { id: "29245d14" }, verb: "posted", (error, doc)->
          activity_id = doc.id
          browser.visit "/activity/#{activity_id}", done

      it "should make name up from actor ID", ->
        assert.equal browser.query(".activity .actor .name").textContent, "Alonso U."

      
    describe "image", ->
      before (done)->
        Activity.create actor: { displayName: "Assaf", image: { url: "http://awe.sm/5hWp5" } }, verb: "posted", (error, doc)->
          activity_id = doc.id
          browser.visit "/activity/#{activity_id}", done
    
      it "should include avatar", ->
        assert.equal browser.query(".activity .actor img.avatar").getAttribute("src"), "http://awe.sm/5hWp5"

      it "should place avatar before display name", ->
        assert browser.query(".activity .actor img.avatar + span.name")


    describe "url", ->
      before (done)->
        Activity.create actor: { displayName: "Assaf", url: "http://labnotes.org", image: { url: "http://awe.sm/5hWp5" } }, verb: "posted", (error, doc)->
          activity_id = doc.id
          browser.visit "/activity/#{activity_id}", done

      it "should link to actor", ->
        assert.equal browser.query(".activity .actor a").getAttribute("href"), "http://labnotes.org"

      it "should place display name inside link", ->
        assert.equal browser.query(".activity .actor a .name").textContent, "Assaf"

      it "should place profile photo inside link", ->
        assert.equal browser.query(".activity .actor img.avatar").getAttribute("src"), "http://awe.sm/5hWp5"


  # Activity verb.
  describe "verb", ->

    before (done)->
      Activity.create actor: { displayName: "Assaf" }, verb: "tested", (error, doc)->
        activity_id = doc.id
        browser.visit "/activity/#{activity_id}", done

    it "should show verb after actor", ->
      assert.equal browser.query(".activity .actor + .verb").textContent, "tested"

      
  # Activity verb.
  describe "object", ->
   
    describe "missing", ->
      before (done)->
        Activity.create actor: { displayName: "Assaf" }, verb: "tested", (error, doc)->
          activity_id = doc.id
          browser.visit "/activity/#{activity_id}", done

      it "should not show object part", ->
        assert !browser.query(".object")

    describe "name only", ->
      before (done)->
        Activity.create actor: { displayName: "Assaf" }, verb: "tested", object: { displayName: "this view" }, (error, doc)->
          activity_id = doc.id
          browser.visit "/activity/#{activity_id}", done

      it "should show object following verb", ->
        assert browser.query(".activity .verb + .object")

      it "should show object display name", ->
        assert.equal browser.query(".activity .object").textContent.trim(), "this view"

    describe "URL only", ->
      before (done)->
        Activity.create actor: { displayName: "Assaf" }, verb: "tested", object: { url: "http://awe.sm/5hWp5" }, (error, doc)->
          activity_id = doc.id
          browser.visit "/activity/#{activity_id}", done

      it "should show object as link", ->
        assert.equal browser.query(".activity .object a").getAttribute("href"), "http://awe.sm/5hWp5"

      it "should show URL as object", ->
        assert.equal browser.query(".activity .object a").textContent, "http://awe.sm/5hWp5"

    describe "name and URL", ->
      before (done)->
        Activity.create actor: { displayName: "Assaf" }, verb: "tested", object: { displayName: "this link", url: "http://awe.sm/5hWp5" }, (error, doc)->
          activity_id = doc.id
          browser.visit "/activity/#{activity_id}", done

      it "should show object as link", ->
        assert.equal browser.query(".activity .object a").getAttribute("href"), "http://awe.sm/5hWp5"

      it "should show display name as object", ->
        assert.equal browser.query(".activity .object a").textContent, "this link"

    describe "with image (no URL)", ->
      before (done)->
        Activity.create actor: { displayName: "Assaf" }, verb: "tested", object: { displayName: "this link", image: { url: "http://awe.sm/5hWp5" } }, (error, doc)->
          activity_id = doc.id
          browser.visit "/activity/#{activity_id}", done

      it "should show image media following object", ->
        assert browser.query(".activity .object + .image.media")

      it "should show media as link to full photo", ->
        assert.equal browser.query(".activity a.image").getAttribute("href"), "http://awe.sm/5hWp5"

      it "should show image", ->
        assert.equal browser.query(".activity a.image img").getAttribute("src"), "http://awe.sm/5hWp5"

    describe "with image (and URL)", ->
      before (done)->
        Activity.create actor: { displayName: "Assaf" }, verb: "tested", object: { displayName: "this link", url: "http://awe.sm/5hbLb", image: { url: "http://awe.sm/5hWp5" } }, (error, doc)->
          activity_id = doc.id
          browser.visit "/activity/#{activity_id}", done

      it "should show image media following object", ->
        assert browser.query(".activity .object + .image.media")

      it "should show media as link to object", ->
        assert.equal browser.query(".activity a.image").getAttribute("href"), "http://awe.sm/5hbLb"

      it "should show image", ->
        assert.equal browser.query(".activity a.image img").getAttribute("src"), "http://awe.sm/5hWp5"


  # Activity time stamp
  describe "timestamp", ->
    before (done)->
      Activity.create actor: { displayName: "Assaf" }, verb: "tested", published: new Date(1331706824865), (error, doc)->
        activity_id = doc.id
        browser.visit "/activity/#{activity_id}", done

    it "should show activity timestamp in current locale", ->
      assert.equal browser.query(".activity .timestamp").textContent, "Tue Mar 13 2012 23:33:44 GMT-0700 (PDT)"


  # Activity location
  describe "location", ->
    before (done)->
      Activity.create actor: { displayName: "Assaf" }, verb: "tested", location: "San Francisco", (error, doc)->
        activity_id = doc.id
        browser.visit "/activity/#{activity_id}", done

    it "should show activity location following timestamp", ->
      assert browser.query(".activity .timestamp + .location")

    it "should show activity location", ->
      assert.equal browser.query(".activity .location").textContent, "From San Francisco"

