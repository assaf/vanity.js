assert = require("assert")
Vanity = require("../")
Helper = require("./helper")


# cb0b203e

describe "split", ->
  vanity      = new Vanity(host: "localhost:3003")
  split       = vanity.split("foo-bar")
  alternative = null

  before Helper.setup


  # -- Adding participant --
  
  describe "add participant with alternative", ->

    describe "no callback", ->
      before ->
        alternative = split.show("8487599a", 1)

      it "should return specified alternative", ->
        assert.equal alternative, 1


    describe "with callback", ->
      before (done)->
        alternative = split.show("f3bfc5a1", 0, done)

      it "should return specified alternative", ->
        assert.equal alternative, 0

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

    it "should not change stored participant", (done)->
      split.get "1cf5814a", (error, { joined, alternative })->
        assert !error
        assert.equal alternative, 3
        assert joined - Date.now() < 1000
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



