Request   = require("request")
name      = require("./names")


# Using this set of verbs
VERBS   = ["posted", "commented", "replied", "mentioned"]


actor = name(Math.random() * 1000)
verb = VERBS[Math.floor(Math.random() * VERBS.length)]
activity =
  actor: { displayName: actor }
  verb: verb
Request.post "http://localhost:3000/v1/activity", json: activity
