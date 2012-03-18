{ setup } = require("./helper")
assert    = require("assert")
Browser   = require("zombie")
Activity  = require("../models/activity")


describe "activity", ->
  browser = new Browser()

  before setup

  # Activity actor.
  describe "actor", ->

    describe "name only", ->
      activity_id = null

      before (done)->
        params =
          actor:
            displayName:  "Assaf"
          verb:           "posted"
        Activity.create params, (error, id)->
          activity_id = id
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
        params =
          actor:
            id:   "29245d14"
          verb:   "posted"
        Activity.create params, (error, activity_id)->
          browser.visit "/activity/#{activity_id}", done

      it "should make name up from actor ID", ->
        assert.equal browser.query(".activity .actor .name").textContent, "Alonso U."

      
    describe "image", ->
      before (done)->
        params =
          actor:
            displayName:  "Assaf"
            image:
              url:        "http://awe.sm/5hWp5"
          verb:           "posted"
        Activity.create params, (error, activity_id)->
          browser.visit "/activity/#{activity_id}", done
    
      it "should include avatar", ->
        assert.equal browser.query(".activity .actor img.avatar").getAttribute("src"), "http://awe.sm/5hWp5"

      it "should place avatar before display name", ->
        assert browser.query(".activity .actor img.avatar + span.name")


    describe "url", ->
      before (done)->
        params =
          actor:
            displayName:  "Assaf"
            url:          "http://labnotes.org"
            image:
              url:        "http://awe.sm/5hWp5"
          verb:           "posted"
        Activity.create params, (error, activity_id)->
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
      params =
        actor:  { displayName: "Assaf" }
        verb:   "tested"
      Activity.create params, (error, activity_id)->
        browser.visit "/activity/#{activity_id}", done

    it "should show verb after actor", ->
      assert.equal browser.query(".activity .actor + .verb").textContent, "tested"

      
  # Activity verb.
  describe "object", ->
   
    describe "missing", ->
      before (done)->
        params =
          actor:  { displayName: "Assaf" }
          verb:   "tested"
        Activity.create params, (error, activity_id)->
          browser.visit "/activity/#{activity_id}", done

      it "should not show object part", ->
        assert !browser.query(".object")

    describe "name only", ->
      before (done)->
        params =
          actor:          { displayName: "Assaf" }
          verb:           "tested"
          object:
            displayName:  "this view"
        Activity.create params, (error, activity_id)->
          browser.visit "/activity/#{activity_id}", done

      it "should show object following verb", ->
        assert browser.query(".activity .verb + .object")

      it "should show object display name", ->
        assert.equal browser.query(".activity .object").textContent.trim(), "this view"

    describe "URL only", ->
      before (done)->
        params =
          actor:  { displayName: "Assaf" }
          verb:   "tested"
          object:
            url:  "http://awe.sm/5hWp5"
        Activity.create params, (error, activity_id)->
          browser.visit "/activity/#{activity_id}", done

      it "should show object as link", ->
        assert.equal browser.query(".activity .object a").getAttribute("href"), "http://awe.sm/5hWp5"

      it "should show URL as object", ->
        assert.equal browser.query(".activity .object a").textContent, "http://awe.sm/5hWp5"

    describe "name and URL", ->
      before (done)->
        params =
          actor:          { displayName: "Assaf" }
          verb:           "tested"
          object:
            displayName:  "this link"
            url:          "http://awe.sm/5hWp5"
        Activity.create params, (error, activity_id)->
          browser.visit "/activity/#{activity_id}", done

      it "should show object as link", ->
        assert.equal browser.query(".activity .object a").getAttribute("href"), "http://awe.sm/5hWp5"

      it "should show display name as object", ->
        assert.equal browser.query(".activity .object a").textContent, "this link"

    describe "with image (no URL)", ->
      before (done)->
        params =
          actor:          { displayName: "Assaf" }
          verb:           "tested"
          object:
            displayName:  "this link"
            image:
              url:        "http://awe.sm/5hWp5"
        Activity.create params, (error, activity_id)->
          browser.visit "/activity/#{activity_id}", done

      it "should show image media following object", ->
        assert browser.query(".activity .object + .image.media")

      it "should show media as link to full photo", ->
        assert.equal browser.query(".activity a.image").getAttribute("href"), "http://awe.sm/5hWp5"

      it "should show image", ->
        assert.equal browser.query(".activity a.image img").getAttribute("src"), "http://awe.sm/5hWp5"

    describe "with image (and URL)", ->
      before (done)->
        params =
          actor:          { displayName: "Assaf" }
          verb:           "tested"
          object:
            displayName:  "this link"
            url:          "http://awe.sm/5hbLb"
            image:
              url:        "http://awe.sm/5hWp5"
        Activity.create params, (error, activity_id)->
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
      params =
        actor:      { displayName: "Assaf" }
        verb:       "tested"
        published:  new Date(1331706824865)
      Activity.create params, (error, activity_id)->
        browser.visit "/activity/#{activity_id}", done

    it "should show activity timestamp in current locale", ->
      assert.equal browser.query(".activity .timestamp").textContent, "Tue Mar 13 2012 23:33:44 GMT-0700 (PDT)"


  # Activity location
  describe "location", ->
    before (done)->
      params =
        actor:      { displayName: "Assaf" }
        verb:       "tested"
        location:   "San Francisco"
      Activity.create params, (error, activity_id)->
        browser.visit "/activity/#{activity_id}", done

    it "should show activity location following timestamp", ->
      assert browser.query(".activity .timestamp + .location")

    it "should show activity location", ->
      assert.equal browser.query(".activity .location").textContent, "From San Francisco, CA, USA"

