assert            = require("assert")
Async             = require("async")
{ EventEmitter }  = require("events")
request           = require("request")
Activity          = require("../models/activity")
search            = require("../config/search")
{ setup }         = require("./helper")
EventSource       = require("./sse_client")


describe "activity", ->
  before setup


  # -- Creating an activity --
  
  describe "post", ->
    statusCode = body = headers = null
    params =
      id:     "8fea081c"
      actor:  { displayName: "Assaf" }
      verb:   "posted"

    describe "valid", ->
      before (done)->
        request.post "http://localhost:3003/activity", json: params, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should create activity", (done)->
        Activity.once "activity", ->
          Activity.get "8fea081c", (error, activity)->
            assert activity
            assert.equal activity.actor.displayName, "Assaf"
            done()

      it "should return 201", ->
        assert.equal statusCode, 201

      it "should return location of new activity", ->
        assert.equal headers["location"], "/activity/8fea081c"

      it "should return empty document", ->
        assert.equal body, " "


    describe "not valid", ->
      before (done)->
        request.post "http://localhost:3003/activity", json: { }, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return 400", ->
        assert.equal statusCode, 400

      it "should return error message", ->
        assert.equal body, "Activity requires verb"


    describe "no body", ->
      before (done)->
        request.post "http://localhost:3003/activity", (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return 400", ->
        assert.equal statusCode, 400

      it "should return error message", ->
        assert.equal body, "Activity requires verb"

    after search.teardown


  # -- Getting an activity --
  
  describe "get activity", ->
    before (done)->
      params =
        id:     "fe936972"
        actor:  { displayName: "Assaf" }
        verb:   "posted"
      Activity.create params, done

    describe "JSON", ->
      statusCode = body = headers = null

      before (done)->
        headers = { "Accept": "application/json" }
        request.get "http://localhost:3003/activity/fe936972", headers: headers, (_, response)->
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

      it "should include HTML representation", ->
        activity = JSON.parse(body)
        assert /^<div/.test(activity.content)

      it "should include activity URL", ->
        activity = JSON.parse(body)
        assert.equal activity.url, "/activity/fe936972"


    describe "HTML", ->

      describe "full page", ->
        statusCode = body = headers = null

        before (done)->
          headers = { "Accept": "text/html" }
          request.get "http://localhost:3003/activity/fe936972", headers: headers, (_, response)->
            { statusCode, headers, body } = response
            done()

        it "should return 200", ->
          assert.equal statusCode, 200

        it "should return an HTML document", ->
          assert /text\/html/.test(headers['content-type'])
          assert /^<!DOCTYPE/.test(body)

      describe "partial", ->
        statusCode = body = headers = null

        before (done)->
          headers =
            "Accept":           "text/html"
            "X-Requested-With": "XMLHttpRequest"
          request.get "http://localhost:3003/activity/fe936972", headers: headers, (_, response)->
            { statusCode, headers, body } = response
            done()

        it "should return 200", ->
          assert.equal statusCode, 200

        it "should return an HTML document fragment", ->
          assert /text\/html/.test(headers['content-type'])
          assert /^<div/.test(body)
          assert !(/html/.test(body))


    describe "any content type", ->
      statusCode = body = headers = null

      before (done)->
        headers = { "Accept": "*/*" }
        request.get "http://localhost:3003/activity/fe936972", headers: headers, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return 200", ->
        assert.equal statusCode, 200

      it "should return an HTML document", ->
        assert /text\/html/.test(headers['content-type'])
        assert /<html/.test(body)


    describe "no such activity", ->
      statusCode = body = headers = null

      before (done)->
        headers = { "Accept": "*/*" }
        request.get "http://localhost:3003/activity/f0000002", headers: headers, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return 404", ->
        assert.equal statusCode, 404

      it "should return an error message", ->
        assert.equal body, "Cannot GET /activity/f0000002"


    after search.teardown
  

  # -- Listing all activities --
  
  describe "list activities", ->
    statusCode = body = headers = null

    before (done)->
      file = require("fs").readFileSync("#{__dirname}/fixtures/activities.json")
      Async.forEach JSON.parse(file), (activity, done)->
        Activity.create activity, done
      , ->
        search (es_index)->
          es_index.refresh done
        

    describe "JSON", ->
      before (done)->
        headers = { "Accept": "application/json" }
        request.get "http://localhost:3003/activity", headers: headers, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return 200", ->
        assert.equal statusCode, 200

      it "should return a JSON document", ->
        assert /application\/json/.test(headers['content-type'])

      it "should return results count", ->
        { total } = JSON.parse(body)
        assert.equal total, 3

      it "should return activities", ->
        { activities } = JSON.parse(body)
        for activity in activities
          assert activity.actor?.displayName

      it "should return most recent activity first", ->
        { activities } = JSON.parse(body)
        names = activities.map("actor").map("displayName")
        assert.deepEqual names, ["David", "Jerome", "Assaf"]

      it "should include HTML representation", ->
        { activities } = JSON.parse(body)
        for activity in activities
          assert /^<div/.test(activity.content)

      it "should include activity URL", ->
        { activities } = JSON.parse(body)
        for activity in activities
          assert /^\/activity\/[0-9a-f]{8}$/.test(activity.url)


    describe "query", ->
      before (done)->
        headers = { "Accept": "application/json" }
        request.get "http://localhost:3003/activity?query=NOT+assaf", headers: headers, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return only matching activities", ->
        { activities } = JSON.parse(body)
        assert.equal activities.length, 2
        assert.equal activities[0].actor.displayName, "David"
        assert.equal activities[1].actor.displayName, "Jerome"

      it "should not return link to next result set", ->
        { next } = JSON.parse(body)
        assert !next

      it "should not return link to previous result set", ->
        { prev } = JSON.parse(body)
        assert !prev

    describe "limit", ->
      before (done)->
        headers = { "Accept": "application/json" }
        request.get "http://localhost:3003/activity?limit=2", headers: headers, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return only N most recent activities", ->
        { activities } = JSON.parse(body)
        assert.equal activities.length, 2
        assert.equal activities[0].actor.displayName, "David"
        assert.equal activities[1].actor.displayName, "Jerome"

      it "should return link to next result set", ->
        { next } = JSON.parse(body)
        assert.equal next, "/activity?limit=2&offset=2"

      it "should not return link to previous result set", ->
        { prev } = JSON.parse(body)
        assert !prev

    describe "offset", ->
      before (done)->
        headers = { "Accept": "application/json" }
        request.get "http://localhost:3003/activity?offset=1&limit=1", headers: headers, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return only N most recent activities, from offset", ->
        { activities } = JSON.parse(body)
        assert.equal activities.length, 1
        assert.equal activities[0].actor.displayName, "Jerome"

      it "should return link to next result set", ->
        { next } = JSON.parse(body)
        assert.equal next, "/activity?limit=1&offset=2"

      it "should return link to previous result set", ->
        { prev } = JSON.parse(body)
        assert.equal prev, "/activity?limit=1&offset=0"

    describe "start", ->
      before (done)->
        headers = { "Accept": "application/json" }
        request.get "http://localhost:3003/activity?start=2011-03-18T18:51:00Z", headers: headers, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return only activities published at/after start time", ->
        { activities } = JSON.parse(body)
        assert.equal activities.length, 2
        assert.equal activities[0].actor.displayName, "David"
        assert.equal activities[1].actor.displayName, "Jerome"

    describe "end", ->
      before (done)->
        headers = { "Accept": "application/json" }
        request.get "http://localhost:3003/activity?end=2011-03-18T18:51:00Z", headers: headers, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return only activities published before start time", ->
        { activities } = JSON.parse(body)
        assert.equal activities.length, 1
        assert.equal activities[0].actor.displayName, "Assaf"

    describe "start/end", ->
      before (done)->
        headers = { "Accept": "application/json" }
        request.get "http://localhost:3003/activity?start=2011-03-18T18:50:30Z&end=2011-03-18T18:51:30Z", headers: headers, (_, response)->
          { statusCode, headers, body } = response
          done()

      it "should return only activities published between start/end time", ->
        { activities } = JSON.parse(body)
        assert.equal activities.length, 1
        assert.equal activities[0].actor.displayName, "Jerome"

    after search.teardown


  # -- Activity stream --
 
  describe "activities stream", ->

    # Collect events sent to event source.
    events = []

    before (done)->
      # Fire up the event source, we need to be connected to receive anything.
      event_source = new EventSource("http://localhost:3003/activity/stream")
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

    after search.teardown
  

  # -- Deleting an activity --
  
  describe "delete", ->
    before (done)->
      params =
        id:     "015f13c4"
        actor:  { displayName: "Assaf" }
        verb:   "posted"
      Activity.create params, ->
        Activity.create id: "75b12975", actor: { displayName: "Assaf" }, verb: "tested", done

    it "should delete activity", (done)->
      request.del "http://localhost:3003/activity/015f13c4", ->
        Activity.get "015f13c4", (error, doc)->
          assert !error && !doc
          done()

    it "should return 204", (done)->
      request.del "http://localhost:3003/activity/015f13c4", (_, response)->
        assert.equal response.statusCode, 204
        done()

    it "should not fail if no such activity", (done)->
      request.del "http://localhost:3003/activity/nosuch", (error, response)->
        assert.equal response.statusCode, 204
        done()

    it "should not delete unrelated activity", (done)->
      Activity.get "75b12975", (error, doc)->
        assert doc && doc.actor
        done()

    after search.teardown


