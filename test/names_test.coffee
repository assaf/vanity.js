assert = require("assert")
File   = require("fs")
{ female, male } = require("../lib/vanity/names")


describe "names", ->

  describe "males", ->
    it "should return James in 3.318 percentile", ->
      assert.equal male(3.318), "James"
      assert.notEqual male(3.319), "James"

    it "should return Wally in 89.939 percentile", ->
      assert.equal male(89.939), "Wally"
      assert.notEqual male(89.940), "Wally"

    it "should return Darell in 90.033 percentile", ->
      assert.equal male(90.033), "Darell"
      assert.notEqual male(90.034), "Darell"

    it "should return Robert in 107 (wrap around) percentile", ->
      assert.equal male(107), "Robert"

    it "should work correctly for all names", ->
      rows = File.readFileSync("#{__dirname}/../lib/vanity/names/us.male.tab", "utf-8").trim().split(/\n/)
      for row in rows
        [name, freq, cumul] = row.split(/\s+/)
        assert.equal name, male(parseFloat(cumul)).toUpperCase()


  describe "females", ->
    it "should return Mary in 2.629 percentile", ->
      assert.equal female(2.629), "Mary"
      assert.notEqual female(2.630), "Mary"

    it "should return Valentina in 84.047 percentile", ->
      assert.equal female(84.047), "Valentina"
      assert.notEqual female(84.048), "Valentina"

    it "should return Alona in 90.023 percentile", ->
      assert.equal female(90.023), "Alona"

    it "should return Barbara in 105 (wrap around) percentile", ->
      assert.equal female(105), "Barbara"

    it "should work correctly for all names", ->
      rows = File.readFileSync("#{__dirname}/../lib/vanity/names/us.female.tab", "utf-8").trim().split(/\n/)
      for row in rows
        [name, freq, cumul] = row.split(/\s+/)
        assert.equal name, female(parseFloat(cumul)).toUpperCase()


