# Exports a function that can turn a string identifier into a suitable display name (given name, followed by first
# letter of family name).
#
# The name is fictitious, however using the same identifier will consistently return the same name.  Different
# identifiers return different names, equally distributed between genders, picking names based on their distribution in
# the US population (e.g. James will show up much more frequently than Darell).
#
# Source is US Census Bureau: # http://www.census.gov/genealogy/names/names_files.html
#
# Example
#   name = require("vanity/name")
#   console.log name("1ff4efbdf")
#   => "Dawn Y."

File          = require("fs")
BTree         = require("./b_tree")
{ hashCode }  = require("../utils")


UPPERCASE = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

female_names = null
male_names = null


# Returns a female name based on a random number between 0 and 100 (exclusive).
female = (percentile)->
  unless female_names
    tree = BTree()
    rows = File.readFileSync("#{__dirname}/us.female.tab", "utf-8").trim().split(/\n/)
    for row in rows
      [given, freq, cumul] = row.split(/\s+/)
      tree.add parseFloat(cumul), given
    female_names = tree.done()

  name = female_names(percentile % 100)
  return name[0] + name[1..].toLowerCase()


# Returns a male name based on a random number between 0 and 100 (exclusive).
male = (percentile)->
  unless male_names
    tree = BTree()
    rows = File.readFileSync("#{__dirname}/us.male.tab", "utf-8").trim().split(/\n/)
    for row in rows
      [given, freq, cumul] = row.split(/\s+/)
      tree.add parseFloat(cumul), given
    male_names = tree.done()

  name = male_names(percentile % 100)
  return name[0] + name[1..].toLowerCase()


# Given an identifier, returns a suitable name (given name, followed by first later of family name).
name = (identifier)->
  hash = hashCode(identifier.toString())
  gender = if hash % 200 >= 100 then female else male
  given = gender(hash % 100)
  family = UPPERCASE[Math.floor(hash / 100) % 26]
  return "#{given} #{family}."


# These functions are added to name for use in test suite.  Everyone else should ignore them.
name.male = male
name.female = female


module.exports = name
