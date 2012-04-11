# To populate ElasticSearch with 1000 activities over 3 days:
#   coffee lib/take_if 1000 localhost:3000
#
# The first argument is number of iterations, optional and defaults to 1000.
#
# The second argument is hostname:port, optional and defaults to localhost:3000.


assert      = require("assert")
Async       = require("async")
Crypto      = require("crypto")
Request     = require("request")
Timekeeper  = require("timekeeper")
BTree       = require("./names/b_tree")
name        = require("./names")
redis       = require("../config/redis")
Activity    = require("../models/activity")
SplitTest   = require("../models/split_test")
require("sugar")


# Number of activities to create
COUNT   = parseInt(process.argv[2] || 1000)
# Distributed over this many days
DAYS    = Math.ceil(COUNT / 300)
# Using this set of verbs
VERBS   = ["posted", "commented", "replied", "mentioned"]
# Labels to choose from
LABELS  = ["funny", "stupid", "smart"]
# Server URL
HOST    = process.argv[3] || "localhost:3000"


# Activities not distributed evenly between hours of the day, use hourly(random) to get a made up distribution
hourly_dist = BTree()
cumul = 0
for hour, pct of [1,1,0,0,1,1,2,4,8,10,12,10, 9,8,6,5,5,4,4,3,2,2,1,1]
  cumul += pct
  hourly_dist.add cumul, hour
assert.equal cumul, 100, "Bad distribution"
hourly = hourly_dist.done()


fakeActivity = (host, count, callback)->
# Delete and re-create index
  queue = []
  console.log "Creating index ..."
  Activity.createIndex ->
    console.log "Populating ElasticSearch with #{COUNT} activities ..."

    for i in [0...COUNT]
      # Random published day within the past DAYS, hour based on the distribution.
      days = Math.floor(Math.random() * DAYS)
      assert days >= 0 && days < DAYS, "Wrong day"
      hour = hourly(Math.random() * 100)
      assert hour >= 0 && hour < 24, "Wrong hour"
      published = Date.create().addDays(-days).addHours(-hour).addMinutes(-Math.random() * 60)

      # Actor name and verb
      actor = name(Math.random() * COUNT / 3)
      verb = VERBS[Math.floor(Math.random() * VERBS.length)]
      assert actor && verb, "Missing actor or verb"
    
      # Pick up to 3 labels
      labels = []
      for j in [1..3]
        label = LABELS[Math.floor(Math.random() * 15)]
        if label
          labels.push label

      activity =
        actor:
          displayName: actor
        verb:        verb
        labels:      labels
      if HOST
        do (activity)->
          queue.push (done)->
            Request.post "http://#{HOST}/v1/activity", json: activity, done
      else
        activity.published = published
        do (activity)->
          queue.push (done)->
            Activity.create activity, done
     
    Async.series queue,
      (error)->
        if error
          callback(error)
        else
          console.log "Published #{COUNT} activities"
          callback()



fakeSplitTest = (count, callback)->
  split = new SplitTest("foo-bar")

  Async.waterfall [
    (done)->
      console.log "Wipe clean any split-test data"
      redis.keys "#{redis.prefix}.*", (error, keys)->
        if keys.length == 0
          done(null, 0)
        else
          redis.del keys..., done

  , (_, done)->
      # Make unique participant identifier
      newId = ->
        Crypto.createHash("md5").update(Math.random().toString()).digest("hex")
      # Load up on identifiers
      ids = (newId() for i in [0...count])
      done(null, ids)

  , (ids, done)->
      Timekeeper.travel Date.create().addDays(-count / 150)
      # Create participants from these IDs.  Do that serially, since we're playing
      # with current time.
      Async.forEachSeries ids, (id, each)->
        Timekeeper.travel Date.create().addMinutes(576) # there are 150 of these in a day
        alternative = Math.floor(Math.random() * 2)
        split.addParticipant id, alternative, ->
          if Math.random() < 0.05
            split.completed id, each
          else
            each()
      , done

  , (done)->
      console.log "Published #{count} data points"
      Timekeeper.reset()
      done()

  ], callback


Async.series [
  (done)->
    fakeActivity HOST, COUNT, done
, (done)->
    fakeSplitTest COUNT, done
], (error)->
  throw error if error
  console.log "Done"
  process.exit 0

