assert    = require("assert")
Async     = require("async")
BTree     = require("./names/b_tree")
name      = require("./names")
Activity  = require("../models/activity")
search    = require("../config/search")
require("sugar")


# Number of activities to create
COUNT   = 5000
# Distributed over this many days
DAYS    = 14
# Using this set of verbs
VERBS   = ["posted", "commented", "replied", "mentioned"]


# Activities not distributed evenly between hours of the day, use hourly(random) to get a made up distribution
hourly_dist = BTree()
cumul = 0
for hour, pct of [1,1,0,0,1,1,2,4,8,10,12,10, 9,8,6,5,5,4,4,3,2,2,1,1]
  cumul += pct
  hourly_dist.add cumul, hour
assert.equal cumul, 100
hourly = hourly_dist.done()


# Only run so many concurrentl
queue = Async.queue((activity, done)->
  Activity.create activity, done
, 5)


# Delete and re-create index
console.log "Deleting index ..."
search.teardown ->
  console.log "Populating ElasticSearch with #{COUNT} activities ..."

  for i in [0...COUNT]
    # Random published day within the past DAYS, hour based on the distribution.
    days = Math.floor(Math.random() * DAYS)
    assert days >= 0 && days < DAYS
    hour = hourly(Math.random() * 100)
    assert hour >= 0 && hour < 24
    published = Date.create().beginningOfDay().addDays(-days).addHours(hour).addMinutes(Math.random() * 60)

    # Actor name and verb
    actor = name(Math.random() * 10000)
    verb = VERBS[Math.floor(Math.random() * VERBS.length)]
    assert actor && verb

    queue.push actor: { displayName: actor }, verb: verb, published: published

process.on "exit", ->
  console.log "Done"
