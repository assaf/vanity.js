Helper            = require("./helper") # must be at top
assert            = require("assert")
Async             = require("async")
{ EventEmitter }  = require("events")
request           = require("request")
Activity          = require("../models/activity")
EventSource       = require("./event_source")


describe "API activity", ->
  before Helper.setup


  # -- Creating an activity --
  
  describe "post", ->
    statusCode = body = headers = null
    params =
      id:       "8fea081c"
      actor:    { displayName: "Assaf" }
      verb:     "posted"
      published: new Date(1332348384734).toISOString()

    before Helper.newIndex

    describe "valid", ->
      before (done)->
        request.post "http://localhost:3003/v1/activity", json: params, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should create activity", (done)->
        Activity.get "8fea081c", (error, activity)->
          assert activity
          assert.equal activity.actor.displayName, "Assaf"
          done()

      it "should return 201", ->
        assert.equal statusCode, 201

      it "should return location of new activity", ->
        assert.equal headers["location"], "/v1/activity/8fea081c"

      it "should return empty document", ->
        assert.equal body, " "


    describe "not valid", ->
      before (done)->
        request.post "http://localhost:3003/v1/activity", json: { }, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return 400", ->
        assert.equal statusCode, 400

      it "should return error message", ->
        assert.equal body, "Activity requires verb"


    describe "no body", ->
      before (done)->
        request.post "http://localhost:3003/v1/activity", (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return 400", ->
        assert.equal statusCode, 400

      it "should return error message", ->
        assert.equal body, "Activity requires verb"


  # -- Getting an activity --
  
  describe "get activity", ->

    before (done)->
      Helper.newIndex ->
        params =
          id:     "fe936972"
          actor:  { displayName: "Assaf" }
          verb:   "posted"
          labels: ["image", "funny"]
        Activity.create params, done

    describe "", ->
      statusCode = body = headers = null

      before (done)->
        headers = { "Accept": "application/json" }
        request.get "http://localhost:3003/v1/activity/fe936972", headers: headers, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return 200", ->
        assert.equal statusCode, 200

      it "should return a JSON document", ->
        assert /application\/json/.test(headers['content-type'])

      it "should return the activity", ->
        activity = JSON.parse(body)
        assert.equal activity.id, "fe936972"
        assert.equal activity.actor.displayName, "Assaf"

      it "should include content", ->
        activity = JSON.parse(body)
        assert.equal activity.content, "Assaf posted."

      it "should include HTML representation", ->
        activity = JSON.parse(body)
        assert /<div/.test(activity.html)

      it "should include activity view URL", ->
        activity = JSON.parse(body)
        assert.equal activity.url, "/activity/fe936972"

      it "should include title", ->
        activity = JSON.parse(body)
        assert.equal activity.title, "Assaf posted."

      it "should include labels", ->
        activity = JSON.parse(body)
        assert activity.labels.include("image")
        assert activity.labels.include("funny")


    describe "no such activity", ->
      statusCode = body = headers = null

      before (done)->
        headers = { "Accept": "*/*" }
        request.get "http://localhost:3003/v1/activity/f0000002", headers: headers, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return 404", ->
        assert.equal statusCode, 404

      it "should return an error message", ->
        assert.equal body, "Not Found"
  

  # -- Listing all activities --
  
  describe "list activities", ->
    statusCode = body = headers = null

    before (done)->
      Helper.newIndex ->
        file = require("fs").readFileSync("#{__dirname}/fixtures/activities.json")
        Async.forEach JSON.parse(file), (activity, done)->
          Activity.create activity, done
        , ->
          Activity.index().refresh done
        

    describe "", ->
      before (done)->
        headers = { "Accept": "application/json" }
        request.get "http://localhost:3003/v1/activity", headers: headers, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return 200", ->
        assert.equal statusCode, 200

      it "should return a JSON document", ->
        assert /application\/json/.test(headers['content-type'])

      it "should return results count", ->
        { totalItems } = JSON.parse(body)
        assert.equal totalItems, 3

      it "should return activities", ->
        { items } = JSON.parse(body)
        for activity in items
          assert activity.actor?.displayName

      it "should return most recent activity first", ->
        { items } = JSON.parse(body)
        names = items.map("actor").map("displayName")
        assert.deepEqual names, ["David", "Jerome", "Assaf"]

      it "should include HTML representation", ->
        { items } = JSON.parse(body)
        for activity in items
          assert /^<div/.test(activity.html)

      it "should include activity view URL", ->
        { items } = JSON.parse(body)
        for activity in items
          assert /^\/activity\/[0-9a-f]{8}$/.test(activity.url)

      it "should include title", ->
        { items } = JSON.parse(body)
        for activity in items
          assert /(Assaf|David|Jerome) (started|continued|completed)\./.test(activity.title)

      it "should return JSON url to full collection", ->
        { url } = JSON.parse(body)
        assert.equal url, "/v1/activity"


    describe "query", ->
      before (done)->
        headers = { "Accept": "application/json" }
        url = "http://localhost:3003/v1/activity?query=NOT+assaf"
        request.get url, headers: headers, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return only matching activities", ->
        { items } = JSON.parse(body)
        assert.equal items.length, 2
        assert.equal items[0].actor.displayName, "David"
        assert.equal items[1].actor.displayName, "Jerome"

      it "should not return link to next result set", ->
        { next } = JSON.parse(body)
        assert !next

      it "should not return link to previous result set", ->
        { prev } = JSON.parse(body)
        assert !prev

      it "should return JSON url to full collection", ->
        { url } = JSON.parse(body)
        assert.equal url, "/v1/activity"


    describe "limit", ->
      before (done)->
        headers = { "Accept": "application/json" }
        url = "http://localhost:3003/v1/activity?limit=2"
        request.get url, headers: headers, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return only N most recent activities", ->
        { items } = JSON.parse(body)
        assert.equal items.length, 2
        assert.equal items[0].actor.displayName, "David"
        assert.equal items[1].actor.displayName, "Jerome"

      it "should return link to next result set", ->
        { next } = JSON.parse(body)
        assert.equal next, "/v1/activity?limit=2&offset=2"

      it "should not return link to previous result set", ->
        { prev } = JSON.parse(body)
        assert !prev


    describe "offset", ->
      before (done)->
        headers = { "Accept": "application/json" }
        url = "http://localhost:3003/v1/activity?offset=1&limit=1"
        request.get url, headers: headers, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return only N most recent activities, from offset", ->
        { items } = JSON.parse(body)
        assert.equal items.length, 1
        assert.equal items[0].actor.displayName, "Jerome"

      it "should return link to next result set", ->
        { next } = JSON.parse(body)
        assert.equal next, "/v1/activity?limit=1&offset=2"

      it "should return link to previous result set", ->
        { prev } = JSON.parse(body)
        assert.equal prev, "/v1/activity?limit=1&offset=0"


    describe "start", ->
      before (done)->
        headers = { "Accept": "application/json" }
        url = "http://localhost:3003/v1/activity?start=2011-03-18T18:51:00Z"
        request.get url, headers: headers, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return only activities published at/after start time", ->
        { items } = JSON.parse(body)
        assert.equal items.length, 2
        assert.equal items[0].actor.displayName, "David"
        assert.equal items[1].actor.displayName, "Jerome"


    describe "end", ->
      before (done)->
        headers = { "Accept": "application/json" }
        url = "http://localhost:3003/v1/activity?end=2011-03-18T18:51:00Z"
        request.get url, headers: headers, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return only activities published before start time", ->
        { items } = JSON.parse(body)
        assert.equal items.length, 1
        assert.equal items[0].actor.displayName, "Assaf"


    describe "start/end", ->
      before (done)->
        headers = { "Accept": "application/json" }
        url = "http://localhost:3003/v1/activity?start=2011-03-18T18:50:30Z&end=2011-03-18T18:51:30Z"
        request.get url, headers: headers, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return only activities published between start/end time", ->
        { items } = JSON.parse(body)
        assert.equal items.length, 1
        assert.equal items[0].actor.displayName, "Jerome"


  # -- Activity stream --
 
  describe "activities stream", ->

    # Collect events sent to event source.
    events = []

    before (done)->
      Helper.newIndex ->
        # Fire up the event source, we need to be connected to receive anything.
        event_source = new EventSource("http://localhost:3003/v1/activity/stream")
        # Wait until we're connected, then create activities and have then sent to event source.
        event_source.onopen = ->
          file = require("fs").readFileSync("#{__dirname}/fixtures/activities.json")
          Async.forEach JSON.parse(file), (activity, done)->
            Activity.create activity, done
          , ->
        # Process activities as they come in.
        event_source.addEventListener "activity", (event)->
          events.push event
          # We only wait for the first three events
          if events.length == 3
            event_source.close()
            done()

    it "should receive all three events", ->
      assert.equal events.length, 3
      # Can't guarantee order of events, must sort
      names = events.map((event)-> JSON.parse(event.data).actor.displayName).sort()
      assert.deepEqual names, ["Assaf", "David", "Jerome"]

    it "events should include url, title and content", ->
      for event in events
        activity = JSON.parse(event.data)
        assert /\/activity\//.test(activity.url)
        assert /(Assaf|David|Jerome) (started|continued|completed)\./.test(activity.title)
        assert /<div/.test(activity.html)


  # -- Deleting an activity --
  
  describe "delete", ->
    before (done)->
      Helper.newIndex ->
        activities = [
          { id: "015f13c4", actor: { displayName: "Assaf" }, verb: "posted" },
          { id: "75b12975", actor: { displayName: "Assaf" }, verb: "tested" }
        ]
        Async.forEach activities, (activity, done)->
          Activity.create activity, done
        , done

    it "should delete activity", (done)->
      request.del "http://localhost:3003/v1/activity/015f13c4", ->
        Activity.get "015f13c4", (error, doc)->
          assert !error && !doc
          done()

    it "should return 204", (done)->
      request.del "http://localhost:3003/v1/activity/015f13c4", (_, response)->
        assert.equal response.statusCode, 204
        done()

    it "should not fail if no such activity", (done)->
      request.del "http://localhost:3003/v1/activity/nosuch", (error, response)->
        assert.equal response.statusCode, 204
        done()

    it "should not delete unrelated activity", (done)->
      Activity.get "75b12975", (error, doc)->
        assert doc && doc.actor
        done()

