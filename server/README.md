# Vanity API and Dashboard


## Running

In development mode, you and run the server under
[Supervisor](https://github.com/isaacs/node-supervisor) with automatic reload on
code change:

```
$ npm start
```

In production, you can run multiple workers with zero down-time deploys using
[Up](https://github.com/LearnBoost/up):

```
$ up config/worker.js
```


## Testing

To run the entire test suite or individual tests and have control over how tests
run and their output, use [Mocha](https://github.com/visionmedia/mocha):

```
$ mocha
```

For automated testing, it's better to default to the `Makefile`, and don't
forget to install the most recent dependencies:

```
$ make install test
```


## Web API

Activities are represented as JSON objects with the following properties:

* `id`        - Universally unique identifier.
* `actor`     - Actor of this activity (required).
* `verb`      - The activity as a verb (e.g. "uploaded file", required)
* `object`    - The object of this activity (e.g. the uploaded file).
* `url`       - Relative path to the HTML page of this activity (read only).
* `title`     - Short JSON/HTML presentation of this activity (read only).
* `content`   - Detailed JSON/HTML presentation of this activity.
* `html`      - HTML presentation of the activity (read only).
* `published` - Timestamp when activity was published (ISO3339).
* `labels`    - Labels to associate with this activity.

Each activity must have a universally unique identifier.  If you attempt to
create two activities with the same identifier, only the first will be stored.
Use a source that provides unique identifiers, such as GUID or UUID.

If you do not provide a unique identifier, one will be created from a SHA of the
activity contents.

Activity actor is required and must include at a minimum `id` or `displayName`.
If the actor specifies an `id` but no `displayName`, the name is made up from
the set of most popular US names.  The same actor identifier will always map to
the same made up name.

An actor may also specify a `url` and `image`.

Activity object is optional.  It may specify the object `displayName`, `url` and
`image`.

Each activity has a published timestamp.  If not supplied when creating the
activity, the current timestamp is used instead.

Each activity may include one or more labels.  Labels are text strings that
allow filtering of activities, e.g. all activities belonging to a project or a
feature.


### Create A New Activity

```
POST /v1/activity
```

The request must be a JSON document providing at the very least an actor and verb.

If the request document is valid, the server returns status code 201 (Created)
and the location of the new activity.  Note that indexing happens
asynchronously, the activity may take some time to appear at that location.

If the request document is invalid, the server returns status code 400 with a
short error message.


### Retrieve Specific Activity

```
GET /v1/activity/:id
```

The response returns a single activity as either JSON document or HTML document
fragment (a `div` element).


### Querying Recent Activities

```
GET /v1/activity
```

The response returns a JSON document with a set of activities that match the
query criteria, starting with the most recent of them.

You can use the following query parameters:
* `query` - Free form query on any of the activity fields
* `limit` - Limit number of activities to return (maximum 250)
* `offset` - Start returning activities from this offset (default 0)
* `start` - Returns activities published at/after this time (ISO3339)
* `end` - Returns activities published before (not including) this time
  (ISO3339)

For example, to retrieve all the activities performed by David that do not
include the verb "posted", during the month of March:

```
GET /v1/activity?query=david+AND+NOT+posted&start=2012-03-01&end=2012-04-01
```

The response document contains the following properties:

* `total` - Total number of activities that match the search criteria
* `activities` - Array of activities that match the search criteria (starting at
  offset, up to limit)
* `next` - Relative path of query to retrieve next set of activities (if not
  last set)
* `prev` - Relative path of query to retrieve previous set of activities (if not
  first set)


### Activity Stream

```
GET /v1/activity/stream
```

Returns a stream of activities as they are published to the server.  The
response is a [server-sent event
stream](http://dev.w3.org/html5/eventsource/#concept-event-stream-reconnection-time).

For example, run this in the browser:

```
events = new EventSource("/activity/stream")
events.addEventListener("activity", function(event) {
  console.log("New activity: " + event.data);
})
```


### Deleting An Activity

```
DELETE /v1/activity/:id
```

