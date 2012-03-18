process.env.NODE_ENV = "test"

Browser   = require("zombie")
Replay    = require("replay")
server    = require("../config/server")


setup = (done)->
  server.listen 3003, done

Browser.site = "localhost:3003"


# To capture and record API calls, run with environment variable RECORD=true
Replay.fixtures = "#{__dirname}/replay"
Replay.networkAccess = false
Replay.localhost "vanity.js"
Replay.ignore "mt1.googleapis.com"


exports.setup = setup
