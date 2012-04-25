assert = require("assert")
Vanity = require("../")
Helper = require("./helper")


describe "split", ->
  vanity = split = alternative = null

  before Helper.once


  # -- Adding participant --
  
  describe "add participant with alternative", ->

    describe "no callback", ->

      before Helper.setup
      before ->
        vanity = new Vanity(url: "http://localhost:3003", token: "secret")
        split  = vanity.split("foo-bar")
        alternative = split.show("8487599a", 0)

      it "should return specified alternative", ->
        assert.equal alternative, 0

      it "should keep alternative in cache", ->
        assert.equal split.show("8487599a"), 0


    describe "with callback", ->

      vanity = new Vanity(url: "http://localhost:3003", token: "secret")
      split  = vanity.split("foo-bar")

      before Helper.setup
      before (done)->
        vanity = new Vanity(url: "http://localhost:3003", token: "secret")
        split  = vanity.split("foo-bar")
        split.show "f3bfc5a1", 0, (error, result)->
          alternative = result
          done()

      it "should pass specified alternative", ->
        assert.equal alternative, 0

      it "should keep alternative in cache", ->
        assert.equal split.show("f3bfc5a1"), 0

      it "should store participant", (done)->
        split.get "f3bfc5a1", (error, { joined, alternative })->
          assert !error
          assert.equal alternative, 0
          assert joined - Date.now() < 1000
          done()

      it "should create test", (done)->
        split.stats (error, stats)->
          assert.equal stats.title, "Foo Bar"
          assert stats.created - Date.now() , 1000
          done()


  describe "add participant without alternative", ->

    describe "no callback", ->

      before Helper.setup
      before ->
        vanity = new Vanity(url: "http://localhost:3003", token: "secret")
        split  = vanity.split("foo-bar")
        alternative = split.show("eb1f4c97")

      it "should return specified alternative", ->
        assert.equal alternative, 1


    describe "with callback", ->

      before Helper.setup
      before (done)->
        split.show "fb0b203e", (error, result)->
          alternative = error || result
          done()

      it "should return alternative", ->
        assert.equal alternative, 0

      it "should store participant", (done)->
        split.get "fb0b203e", (error, { joined, alternative })->
          assert !error
          assert.equal alternative, 0
          assert joined - Date.now() < 1000
          done()


  describe "add participant twice", ->

    before Helper.setup
    before (done)->
      vanity = new Vanity(url: "http://localhost:3003", token: "secret")
      split  = vanity.split("foo-bar")
      split.show "1cf5814a", true, ->
        split.show "1cf5814a", false, (error, result)->
          alternative = error || result
          done()

    it "should return first alternative", ->
      assert.equal alternative, 1

    it "should keep first alternative in cache", ->
      assert.equal split.show("1cf5814a"), 1

    it "should not change stored participant", (done)->
      split.get "1cf5814a", (error, { joined, alternative })->
        assert !error
        assert.equal alternative, 1
        assert joined - Date.now() < 1000
        done()


  # -- Completing split test --
  
  describe "add participant and complete", ->

    before Helper.setup
    before (done)->
      vanity = new Vanity(url: "http://localhost:3003", token: "secret")
      split  = vanity.split("foo-bar")
      split.show("79d778d8")
      split.completed "79d778d8", (error, result)->
        done()

    it "should store alternative", (done)->
      split.get "79d778d8", (error, { joined, alternative })->
        assert.equal alternative, 0
        assert joined - Date.now() < 1000
        done()

    it "should store completion", (done)->
      split.get "79d778d8", (error, { completed })->
        assert completed - Date.now() < 1000
        done()


  describe "just complete", ->

    before Helper.setup
    before (done)->
      vanity = new Vanity(url: "http://localhost:3003", token: "secret")
      split  = vanity.split("foo-bar")
      split.completed "163b06c0", (error, result)->
        done()

    it "should not create participant", (done)->
      split.get "163b06c0", (error, result)->
        assert !error
        assert !result
        done()


  # -- Error handling --
  
  describe "errors", ->
    before ->
      vanity = new Vanity(url: "http://localhost:3003", token: "secret")
      split  = vanity.split("foo-bar")
  
    describe "invalid test name", ->

      it "should throw error", ->
        try
          vanity.split("foo+bar")
        catch error
          return
        assert false, "Expected an error"

    describe "no participant", ->

      it "should throw error", ->
        try
          split.show()
        catch error
          return
        assert false, "Expected an error"

    describe "not connected", ->
      broken = new Vanity(url: "http://nosuch", token: "secret")

      it "should not throw error when adding participant", ->
        broken.split("foo-bar").show("6a59a671")

      it "should not throw error when completing test", ->
        broken.split("foo-bar").completed("6a59a671")

      it "should not throw error when getting participant", (done)->
        broken.split("foo-bar").get "6a59a671", (error)->
          assert error
          done()


  # -- Explicit --
  
  describe "showA", ->

    describe "no callback", ->

      before Helper.setup
      before ->
        vanity = new Vanity(url: "http://localhost:3003", token: "secret")
        split  = vanity.split("foo-bar")
        alternative = split.showA("30e95dc")

      it "should return specified alternative", ->
        assert.equal alternative, 0


    describe "with callback", ->

      vanity = new Vanity(url: "http://localhost:3003", token: "secret")
      split  = vanity.split("foo-bar")

      before Helper.setup
      before (done)->
        vanity = new Vanity(url: "http://localhost:3003", token: "secret")
        split  = vanity.split("foo-bar")
        split.showA "30e95dc", (error, result)->
          alternative = result
          done()

      it "should pass specified alternative", ->
        assert.equal alternative, 0

  
  describe "showB", ->

    describe "no callback", ->

      before Helper.setup
      before ->
        vanity = new Vanity(url: "http://localhost:3003", token: "secret")
        split  = vanity.split("foo-bar")
        alternative = split.showB("0e935dca")

      it "should return specified alternative", ->
        assert.equal alternative, 0


    describe "with callback", ->

      vanity = new Vanity(url: "http://localhost:3003", token: "secret")
      split  = vanity.split("foo-bar")

      before Helper.setup
      before (done)->
        vanity = new Vanity(url: "http://localhost:3003", token: "secret")
        split  = vanity.split("foo-bar")
        split.showB "0e935dca", (error, result)->
          alternative = result
          done()

      it "should pass specified alternative", ->
        assert.equal alternative, 0


  # -- Conflicts --

  describe "conflicting alternatives", ->
    splitA = splitB = null
    faceValue = null

    describe "specified", ->

      before Helper.setup
      before (done)->
        vanityA = new Vanity(url: "http://localhost:3003", token: "secret")
        splitA  = vanityA.split("foo-bar")
        vanityB = new Vanity(url: "http://localhost:3003", token: "secret")
        splitB  = vanityB.split("foo-bar")

        # Client A sets the alternative to 3 and
        splitA.show "cb0b203e", true, ->
          # Client B comes next ..
          # Set the alternative to 2.  This is now the at-face value.
          splitB.show("cb0b203e", false)
          faceValue = splitB.show("cb0b203e")
          # Get talking to the server
          splitB.show "cb0b203e", (error, alternative)->
            # Let's see what's in the cache now ..
            second = splitB.show("cb0b203e")
            done()

      it "should accept initial value", ->
        assert.equal faceValue, false

      it "should correct to original alternative", ->
        # Let's see what's in the cache now ..
        assert.equal splitB.show("cb0b203e"), true

      it "should ignore any alternative we specify", ->
        assert.equal splitB.show("cb0b203e", 1), true

