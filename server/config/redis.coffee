Redis  = require("redis")
config = require("./index")

redis = Redis.createClient(config.redis.port, config.redis.hostname)
redis.prefix = config.redis.prefix


module.exports = redis
