server   = require("./config/server")
Activity = require("./models/activity")

Activity.createIndex ->
  server.listen process.env.PORT || 3000
