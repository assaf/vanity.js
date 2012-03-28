logger   = require("../config/logger")
server   = require("../config/server")

Redis  = require("redis")
redis = Redis.createClient() #port, hostname)


server.post "/v1/split/:test/:id", (req, res, next)->
  { test, id } = req.params
  redis.hsetnx "vanity.split.#{test}.joined", "joined", Date.create(), ->
    console.log arguments
  if req.body.alternative
    redis.hsetnx "vanity.split.#{test}.#{id}", "alt", req.body.alternative, ->
      console.log arguments
  res.send {}
