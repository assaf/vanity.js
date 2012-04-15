# Vanity API and Dashboard


## Running

In development mode you can run a single server instance with automatic
reloading using:

```
$ npm start
```

In production, you can run multiple workers with zero down-time deploys using
[Up](https://github.com/LearnBoost/up):

```
$ NODE_ENV=production node server.js
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


## Web API for Activity Stream

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


## Web API for Split Tests

### List Tests

```
PUT /v1/split
```

Returns a list of all active split test.

Response JSON document includes a single property `tests` with an array of split
tests, each an object with the following properties:
* `id`      - Test identifier
* `title`   - Human readable title
* `created` - Timestamp when test was created

### Get Test Results

```
PUT /v1/split/:test
```

Returns information about a split test.

Response json document includes the following properties:
* `id`            - Test identifier
* `title`         - Human readable title
* `created`       - Timestamp when test was created
* `alternatives`  - Array of alternatives

Each alternative includes the following properties:
* `title`         - Title of this alternative
* `participants`  - Number of participants in this test
* `completed`     - Number of participants that completed this test
* `data`          - Time series data

Time series data is an array of entries, one for each hour, consisting of:
* `time`          - The time
* `participants`  - Number of participants in this test
* `completed`     - Number of participants that completed this test

If the test does not exist, returns status code 404.

### Add Participant

```
POST /v1/split/:test/:participant
```

Send this request to indicate participant joined the test.

Request path specifies the test and participant identifier.

The request document must specify a single parameter (in any supported media
type):
* `alternative` - The alternative chosen for this participant, either 0 (A) or 1
  (B)

Returns status code 200 and a JSON document with one property:
* `alternative` - The alternative decided for this participant

If the test identifier or alternative are invalid, the request returns status
code 400.

### Record Completion

```
POST /v1/split/:test/:participant/completed
```

Send this request to indicate participant completed the test (converted).

Request path specifies the test and participant identifier.

Returns status code 204 (No content).

### Retrieve Participant

```
GET /v1/split/:test/:participant
```

Returns information about participant.

Request path specifies the test and participant identifier.

Response JSON document includes the following properties:
* `participant` - Identifier
* `joined`      - Timestamp when participant joined experiment
* `alternative` - Alternative number
* `completed`   - Timestamp when participant completed experiment
* `outcome`     - Recorded outcome

If the participant never joined this split test, the request returns status code
404.

