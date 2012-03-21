server = require("./config/server")
search = require("./config/search")

search ->
  server.listen process.env.PORT || 3000
