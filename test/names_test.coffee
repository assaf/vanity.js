assert = require("assert")
File   = require("fs")
name   = require("../lib/vanity/name")
{ male, female } = name


describe "names", ->
  unique = (source)->
    return source.reduce((array, value)->
      unless ~array.indexOf(value)
        array.push value
      return array
    , [])


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
      rows = File.readFileSync("#{__dirname}/../lib/vanity/name/us.male.tab", "utf-8").trim().split(/\n/)
      for row in rows
        [given, freq, cumul] = row.split(/\s+/)
        assert.equal given, male(parseFloat(cumul)).toUpperCase()


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
      rows = File.readFileSync("#{__dirname}/../lib/vanity/name/us.female.tab", "utf-8").trim().split(/\n/)
      for row in rows
        [given, freq, cumul] = row.split(/\s+/)
        assert.equal given, female(parseFloat(cumul)).toUpperCase()


  describe "from ID", ->
    it "should return given name and first letter of family name", ->
      assert.equal name("85bb3cfe1"), "Lester G."

    it "should return female names", ->
      assert.equal name("1ff4efbdf"), "Dawn Y."

    it "should return male names", ->
      assert.equal name("7864c456f"), "Bobby Y."

    it "should return same name consistently for same ID", ->
      ids = ["07F9F5E2F3", "07F9F5E2F3", "07F9F5E2F3", "07F9F5E2F3", "07F9F5E2F3", "07F9F5E2F3"]
      names = ids.map((id)-> name(id)).sort()
      assert.deepEqual unique(names), ["Christina S."]

    it "should return different name for different ID", ->
      ids = ["07F9F5E2F3", "31F509B60E", "CDE02B9F4B", "D624D97240", "6913D09DA8", "8E44C8C990"]
      names = ids.map((id)-> name(id)).sort()
      assert.deepEqual unique(names), ["Alonso M.","Christina S.","Eric Q.","Janet I.","Nancy U.","Trista A."]

