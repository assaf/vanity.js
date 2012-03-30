assert = require("assert")
Vanity = require("../")
Helper = require("./helper")


describe "split", ->
  vanity      = new Vanity(host: "localhost:3003")
  split       = vanity.split("foo-bar")
  alternative = null

  before Helper.setup


  # -- Adding participant --
  
  describe "add participant with alternative", ->

    describe "no callback", ->
      before ->
        alternative = split.show("8487599a", 0)

      it "should return specified alternative", ->
        assert.equal alternative, 0

      it "should keep alternative in cache", ->
        assert.equal split.show("8487599a"), 0


    describe "with callback", ->
      before (done)->
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



  describe "add participant without alternative", ->

    describe "no callback", ->
      before ->
        alternative = split.show("eb1f4c97")

      it "should return specified alternative", ->
        assert.equal alternative, 1


    describe "with callback", ->
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
    before (done)->
      split.show "1cf5814a", 3, ->
        split.show "1cf5814a", 2, (error, result)->
          alternative = error || result
          done()

    it "should return first alternative", ->
      assert.equal alternative, 3

    it "should keep first alternative in cache", ->
      assert.equal split.show("1cf5814a"), 3

    it "should not change stored participant", (done)->
      split.get "1cf5814a", (error, { joined, alternative })->
        assert !error
        assert.equal alternative, 3
        assert joined - Date.now() < 1000
        done()


  # -- Completing split test --
  
  describe "add participant and complete", ->
    outcome = null

    describe "no value", ->
      before (done)->
        split.show("79d778d8")
        split.completed "79d778d8", (error, result)->
          outcome = result
          done()

      it "should set outcome to zero", ->
        assert.equal outcome, 0

      it "should store alternative", (done)->
        split.get "79d778d8", (error, { joined, alternative })->
          assert.equal alternative, 0
          assert joined - Date.now() < 1000
          done()

      it "should store outcome", (done)->
        split.get "79d778d8", (error, { completed, outcome })->
          assert.equal outcome, 0
          assert completed - Date.now() < 1000
          done()


    describe "with value", ->
      before (done)->
        split.show("23c5b1da")
        split.completed "23c5b1da", 5, (error, result)->
          outcome = result
          done()

      it "should set outcome to five", ->
        assert.equal outcome, 5

      it "should store outcome", (done)->
        split.get "23c5b1da", (error, { completed, outcome })->
          assert.equal outcome, 5
          assert completed - Date.now() < 1000
          done()


  describe "just complete", ->
    outcome = null

    before (done)->
      split.completed "163b06c0", (error, result)->
        outcome = result
        done()

    it "should set outcome to zero", ->
      assert.equal outcome, 0

    it "should store alternative", (done)->
      split.get "163b06c0", (error, { joined, alternative })->
        assert.equal alternative, 1
        assert joined - Date.now() < 1000
        done()

    it "should store outcome", (done)->
      split.get "163b06c0", (error, { completed, outcome })->
        assert.equal outcome, 0
        assert completed - Date.now() < 1000
        done()


  describe "two completions", ->
    outcome = null

    before (done)->
      split.completed "3f8aab31", 7, (error, result)->
        split.completed "3f8aab31", 9, (error, result)->
          outcome = result
          done()

    it "should set outcome to first value", ->
      assert.equal outcome, 7

    it "should store first value", (done)->
      split.get "3f8aab31", (error, { completed, outcome })->
        assert.equal outcome, 7
        assert completed - Date.now() < 1000
        done()


  # -- Error handling --
  
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

  describe "alternative is NaN", ->

    it "should throw error", ->
      try
        split.show("1cf5814a", "foo")
      catch error
        return
      assert false, "Expected an error"

  describe "alternative is negative", ->

    it "should throw error", ->
      try
        split.show("1cf5814a", -1)
      catch error
        return
      assert false, "Expected an error"

  describe "alternative is not integer", ->

    it "should throw error", ->
      try
        split.show("1cf5814a", 1.2)
      catch error
        return
      assert false, "Expected an error"

  describe "outcome is a string", ->

    it "should throw error", ->
      try
        split.completed("1cf5814a", "foo")
      catch error
        return
      assert false, "Expected an error"

  describe "outcome is null", ->

    it "should throw error", ->
      try
        split.completed("1cf5814a", null)
      catch error
        return
      assert false, "Expected an error"


  # -- Conflicts --

  describe "conflicting alternatives", ->
    split2 = null
    faceValue = null

    describe "specified", ->

      before (done)->
        # Client A sets the alternative to 3 and
        split.show "cb0b203e", 3, ->
          # Client B comes next ..
          vanity2 = new Vanity(host: "localhost:3003")
          split2  = vanity2.split("foo-bar")
          # Set the alternative to 2.  This is now the at-face value.
          split2.show("cb0b203e", 2)
          faceValue = split2.show("cb0b203e")
          # Get talking to the server
          split2.show "cb0b203e", (error, alternative)->
            # Let's see what's in the cache now ..
            second = split2.show("cb0b203e")
            done()

      it "should accept initial value", ->
        assert.equal faceValue, 2

      it "should correct to original alternative", ->
        # Let's see what's in the cache now ..
        assert.equal split2.show("cb0b203e"), 3

      it "should ignore any alternative we specify", ->
        assert.equal split2.show("cb0b203e", 1), 3

