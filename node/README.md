# Vanity.js Node Client


#### Vanity(options)

Options are:

* host   - Host name of vanity server (may include port, e.g.
  "vanity.interna:443")
* token  - Access token

```
var Vanity = require("vanity"),
    vanity = new Vanity({ host: "vanity.internal:443", token: "secret token" });

vanity.activity({ actor: "Assaf", verb: "shared", object: "http://bit.ly/GLUa9S" })
```


## Activity Stream


#### vanity.activity(activity)

* id       - Unique activity identifier.  Optional.
* actor    - Activity actor is either a name (string) or an object.
* verb     - Activity performed.
* object   - Object associated with the activity, either display name (string)
  or an object.  Optional. 
* location - Location name.  Optional.
* label    - Labels.  Optional.

Actor may specify id and/or displayName, and optionally also url (to profile)
and image.  If you don't have a displayName, just pass the id, and Vanity will
make up a name for you.  If you only have the display name, you can pass it
directly as a string argument.

Object may specify url and/or displayName, and optionally also an image.  If you
don't have a displayName, url will be shown as the object descriptor.  If you
only have the display name, you can pass it directly as a string argument.

Image must specify url and may specify height and width in pixels.

For example:

```
vanity.activity({ actor: "Assaf", verb: "shared", object: "http://bit.ly/GLUa9S" })

vanity.activity({
  actor: {
    id: "assaf",
    displayName: "Assaf",
    url: "http://labnotes.org/"
  },
  verb: "shared",
  object: {
    displayName: "hjkl",
    url: "http://t.co/dKh54pQK",
    image: {
      url: "http://bit.ly/yq14vJ"
    }
  },
  location: "San Francisco, CA",
  labels: ["funny"]
})
```


## Split Testing

#### vanity.split(id)

Returns a split test (`SplitTest`).

Arguments are:

* id - Test identifier (alphanumeric/underscore/hyphen)

Returns a `SplitTest` object.


#### splittest.show(participant, alternative, callback)

Use this when choosing which alternative to show.

If you want Vanity to pick up which alternative to show, call with one argument
(participant identifier) and it will return an alternative number.  This request
updates the server but returns immediately without waiting for response.

Example:

```
if (split.show(userId))
  render("optionB"); // Alternative 1 that we're testing
else
  render("optionA"); // Alternative 0, our base line
```

You can also call with participant and callback.  This will contact the server,
wait for response, and return the actual alternative number.  This is the safest
way to get the alternative.

Example:

```
split.show(userId, function(error, alternative) {
  if (alternative)
    render("optionB"); // Alternative 1 that we're testing
  else
    render("optionA"); // Alternative 0, our base line
})
```

You can also force a particular alternative by calling with participant,
alternative number and optional callback.  Note that an alternative can be set
only once.  With a callback, you'll get the alternative stored on the server,
which may differ from the one passed as argument.

Example:

```
// These users always sees the second option
if (user.beta)
  split.show(userId, 1);
split.show(userId, function(error, alternative) {
  . . .
})
```


#### splittest.completed(participant, outcome, callback)


Use this to record conversion (goal completion).

Example:

```
split.completed(userId)
```

If you want to wait for response from the server, pass a callback as the second
argument.

You can call this method multiple times for a given participant, only the first
call has any affect.  You can call this method without first calling `show`, and
it will also add the participant to the experiment.



#### splittest.get(participant, callback)

Retrieve all that is known about a participant.

Arguments are:

* participant - Participant identifier
* callback    - Call with error and result (null if no participant)

Result contains:

* participant - Participant identifier
* alternative - Alternative number
* joined      - When participant joined the test (Date)
* outcome     - Outcome
* completed   - When participant completed the test (Date)

