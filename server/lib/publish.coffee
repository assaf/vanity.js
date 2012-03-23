Vanity   = require("vanity")
name     = require("./names")


# Using this set of verbs
VERBS   = ["posted", "commented", "replied", "mentioned"]


actor = name(Math.random() * 1000)
verb = VERBS[Math.floor(Math.random() * VERBS.length)]
activity =
  actor: { displayName: actor }
  verb: verb
vanity = new Vanity(host: "localhost:3000")
vanity.on "error", console.error
vanity.activity activity
