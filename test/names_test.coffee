assert = require("assert")
File   = require("fs")
name   = require("../lib/vanity/names")
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
      sample =
        JAMES:       3.318
        JOHN:        6.589
        ROBERT:      9.732
        MICHAEL:    12.361
        WILLIAM:    14.812
        FRED:       53.241
        WAYNE:      53.490
        BILLY:      53.738
        STEVE:      53.984
        LOUIS:      54.227
        WESLEY:     69.760
        GORDON:     69.864
        DEAN:       69.968
        GREG:       70.071
        JORGE:      70.175
        EDUARDO:    78.559
        TERRENCE:   78.606
        ENRIQUE:    78.652
        FREDDIE:    78.698
        WADE:       78.743
        AUSTIN:     78.786
        ELDEN:      90.026
        DORSEY:     90.029
        DARELL:     90.033
        BRODERICK:  90.036
        ALONSO:     90.040
      for given, cumul of sample
        assert.equal given, male(cumul).toUpperCase()


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
      sample =
        MARY:        2.629
        PATRICIA:    3.702
        LINDA:       4.736
        BARBARA:     5.716
        ELIZABETH:   6.653
        GUADALUPE:  66.626
        BELINDA:    66.685
        MARGARITA:  66.743
        SHERYL:     66.802
        CORA:       66.860
        RUTHIE:     78.930
        NELDA:      78.944
        MINERVA:    78.958
        LILLY:      78.973
        TERRIE:     78.987
        LETHA:      79.001
        FAYE:       66.917
        GENA:       80.748
        BRIANA:     80.758
        TIESHA:     87.648
        TAKISHA:    87.650
        STEFFANIE:  87.652
        SINDY:      87.654
        SANTANA:    87.656
        MEGHANN:    87.658
        KAYCEE:     89.545
        KALYN:      89.546
        JOYA:       89.547
        JOETTE:     89.548
        JENAE:      89.549
        JANIECE:    89.550
        ARDELIA:    90.020
        ANNELLE:    90.021
        ANGILA:     90.022
        ALONA:      90.023
        ALLYN:      90.024
      for given, cumul of sample
        assert.equal given, female(cumul).toUpperCase()


  describe "from ID", ->
    it "should return given name and first letter of family name", ->
      assert.equal name("85bb3cfe1"), "Willie I."

    it "should return female names", ->
      assert.equal name("1ff4efbdf"), "Dawn A."

    it "should return male names", ->
      assert.equal name("7864c456f"), "James A."

    it "should return same name consistently for same ID", ->
      ids = ["07F9F5E2F3", "07F9F5E2F3", "07F9F5E2F3", "07F9F5E2F3", "07F9F5E2F3", "07F9F5E2F3"]
      names = ids.map((id)-> name(id)).sort()
      assert.deepEqual unique(names), ["Lester S."]

    it "should return different name for different ID", ->
      ids = ["07F9F5E2F3", "31F509B60E", "CDE02B9F4B", "D624D97240", "6913D09DA8", "8E44C8C990"]
      names = ids.map((id)-> name(id)).sort()
      assert.deepEqual unique(names), ["Alfonso O.", "Alicia Q.", "Christopher I.", "Goldie I.", "Lester S."]

