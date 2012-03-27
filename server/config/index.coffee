# Exports configuration object for the current environment (NODE_ENV).
CoffeeScript = require("coffee-script")
File         = require("fs")
Path         = require("path")

# Since everything loads this somehow, best place to include Sugar.js
# This enhances built-in classes, so a global require
require "sugar"


# Default mode is development
process.env.NODE_ENV = (process.env.NODE_ENV || "development").toLowerCase()

# Load the give CoffeeScript file and evaluate it as a map.
load = (filename)->
  script = File.readFileSync(filename, "utf-8").split("\n").map((l)-> "  " + l).join("\n")
  wrapped = "config = \n#{script}\nreturn config"
  return eval(CoffeeScript.compile(wrapped))

# Load default configuration file, and enhance it with configuration file for
# the given environment.
config = load("#{__dirname}/default.config")
env_fn = "#{__dirname}/#{process.env.NODE_ENV}.config"
if Path.existsSync(env_fn)
  env_config = load(env_fn)
  for name, value of env_config
    config[name] = value


module.exports = config
