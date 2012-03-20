server = require("./config/server")
search = require("./config/search")

search ->
  server.listen 3000
