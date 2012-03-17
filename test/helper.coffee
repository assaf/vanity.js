process.env.NODE_ENV = "test"

Browser   = require("zombie")
Replay    = require("replay")
Search    = require("../lib/vanity/search")
dashboard = require("../lib/vanity/dashboard")


setup = (done)->
  dashboard.listen 3003, ->
    Search.initialize done

Browser.site = "localhost:3003"


# To capture and record API calls, run with environment variable RECORD=true
Replay.fixtures = "#{__dirname}/replay"
Replay.networkAccess = false
Replay.localhost "vanity.js"
Replay.ignore "mt1.googleapis.com"


exports.setup = setup
