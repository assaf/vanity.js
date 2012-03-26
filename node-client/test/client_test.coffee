assert = require("assert")
Vanity = require("../")
Helper  = require("./helper")


describe "activity", ->
  activity   = null
  last_error = null
  vanity     = new Vanity(host: "localhost:3003")

  before (done)->
    vanity.on "error", (error)->
      last_error = error
    Helper.setup done


  describe "full parameters", ->

    before (done)->
      last_error = null
      vanity.activity
        id:     "df7dcf7d6648559da6eea01e9f55f914c7ce30f3"
        actor:
          id:           "assaf"
          displayName:  "Assaf"
          url:          "http://labnotes.org"
          image:
            url:        "https://en.gravatar.com/userimage/3621225/d6f077ea1e5db61afad13eeb5e79e7a2.jpeg"
            width:      80
            height:     90
        verb:     "shared"
        object:
          displayName:  "victory dance"
          url:          "https://gimmebar.com/view/4f19d99a2e0aaa3f1300006f"
          image:
            url:        "https://gimmebar.com/view/4f19d99a2e0aaa3f1300006f"
            width:      300
            height:     200
        location: "San Francisco"
        labels:   ["funny", "die"]
      Helper.search (activities)->
        activity = activities[0]
        done()
      
    it "should create activity on server", ->
      assert activity

    it "should use id", ->
      assert.equal activity.id, "df7dcf7d6648559da6eea01e9f55f914c7ce30f3"

    it "should use designated actor parameters", ->
      assert.equal activity.actor.id, "assaf"
      assert.equal activity.actor.displayName, "Assaf"
      assert.equal activity.actor.url, "http://labnotes.org/" # Note: trailing slash added by Vanity
      assert.equal activity.actor.image.url, "https://en.gravatar.com/userimage/3621225/d6f077ea1e5db61afad13eeb5e79e7a2.jpeg"
      assert.equal activity.actor.image.width, 80
      assert.equal activity.actor.image.height, 90

    it "should use verb parameter", ->
      assert.equal activity.verb, "shared"

    it "should use designated object parameters", ->
      assert.equal activity.object.displayName, "victory dance"
      assert.equal activity.object.url, "https://gimmebar.com/view/4f19d99a2e0aaa3f1300006f"
      assert.equal activity.object.image.url, "https://gimmebar.com/view/4f19d99a2e0aaa3f1300006f"
      assert.equal activity.object.image.width, 300
      assert.equal activity.object.image.height, 200

    it "should use location parameter", ->
      assert.equal activity.location.displayName, "San Francisco, CA, USA"

    it "should use labels parameter", ->
      assert ~activity.labels.indexOf("funny")
      assert ~activity.labels.indexOf("die")

    it "should not emit an error", ->
      assert !last_error

    after Helper.teardown


  describe "short parameters", ->

    before (done)->
      last_error = null
      vanity.activity
        actor:    "Assaf"
        verb:     "shared"
        object:   "victory dance"
        location: "San Francisco"
      Helper.search (activities)->
        activity = activities[0]
        done()
      
    it "should create activity on server", ->
      assert activity

    it "should create id", ->
      assert /^[a-f0-9]{16,}$/.test(activity.id)

    it "should use designated actor name", ->
      assert.equal activity.actor.displayName, "Assaf"
      assert !activity.actor.id
      assert !activity.actor.url
      assert !activity.actor.image

    it "should use verb parameter", ->
      assert.equal activity.verb, "shared"

    it "should use designated object name", ->
      assert.equal activity.object.displayName, "victory dance"
      assert !activity.object.url
      assert !activity.object.image

    it "should use location parameter", ->
      assert.equal activity.location.displayName, "San Francisco, CA, USA"

    it "should not emit an error", ->
      assert !last_error

    after Helper.teardown


  describe "minimum parameters", ->

    before (done)->
      last_error = null
      vanity.activity
        actor:    "Assaf"
        verb:     "shared"
      Helper.search (activities)->
        activity = activities[0]
        done()
      
    it "should create activity on server", ->
      assert activity

    it "should create id", ->
      assert /^[a-f0-9]{16,}$/.test(activity.id)

    it "should use designated actor name", ->
      assert.equal activity.actor.displayName, "Assaf"
      assert !activity.actor.id
      assert !activity.actor.url
      assert !activity.actor.image

    it "should use verb parameter", ->
      assert.equal activity.verb, "shared"

    it "should have no object", ->
      assert.equal activity.object, undefined

    it "should have no location", ->
      assert.equal activity.location, undefined

    it "should not emit an error", ->
      assert !last_error

    after Helper.teardown


  describe "missing parameters", ->
    before (done)->
      last_error = null
      vanity.activity {}
      Helper.search (activities)->
        activity = activities[0]
        done()
      
    it "should create no activity on server", ->
      assert !activity

    it "should emit an error", ->
      assert.equal last_error, "Server returned 400: Activity requires verb"

    after Helper.teardown


  describe "no host name", ->

    before (done)->
      last_error = null
      nohost = new Vanity()
      nohost.on "error", (error)->
        last_error = error
      nohost.activity
        actor:    "Assaf"
        verb:     "shared"
      Helper.search (activities)->
        activity = activities[0]
        done()
      
    it "should not create activity on server", ->
      assert !activity

    it "should not emit an error", ->
      assert !last_error

    after Helper.teardown


  describe "no error handler", ->

    before (done)->
      last_error = null
      nohandler = new Vanity(host: "localhost:3003")
      nohandler.activity actor: "Assaf"
      done()
      
    it "should not blow up on uncaughtException", ->
      assert true

    it "should not emit an error", ->
      assert !last_error

    after Helper.teardown
