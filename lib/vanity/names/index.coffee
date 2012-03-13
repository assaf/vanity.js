File = require("fs")
Tree = require("../name_tree")


Names =

  # Returns a female name based on a random number between 0 and 100 (exclusive).
  female: (percentile)->
    percentile ||= Math.random() * 100
    unless Names._females
      tree = new Tree()
      rows = File.readFileSync("#{__dirname}/us.female.tab", "utf-8").trim().split(/\n/)
      for row in rows
        [name, freq, cumul] = row.split(/\s+/)
        tree.add parseFloat(cumul), name
      Names._females = tree.done()

    name = Names._females(percentile % 100)
    return name[0] + name[1..].toLowerCase()

  # Returns a male name based on a random number between 0 and 100 (exclusive).
  male: (percentile)->
    percentile ||= Math.random() * 100
    unless Names._males
      tree = new Tree()
      rows = File.readFileSync("#{__dirname}/us.male.tab", "utf-8").trim().split(/\n/)
      for row in rows
        [name, freq, cumul] = row.split(/\s+/)
        tree.add parseFloat(cumul), name
      Names._males = tree.done()

    name = Names._males(percentile % 100)
    return name[0] + name[1..].toLowerCase()


module.exports = Names
