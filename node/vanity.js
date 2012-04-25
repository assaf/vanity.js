// Exports constructor for a Vanity client.
//
// Example:
//   var Vanity = require("vanity"),
//       vanity = new Vanity({ host: "vanity.internal:443", token: "secret token" });
//
//   vanity.activity({ actor: "Assaf", verb: "shared", object: "http://bit.ly/GLUa9S" })


var Request = require("request"),
    Util    = require("util"),
    Events  = require("events");


// Constructs a new Vanity client.  Options are:
// host   - Host name of vanity server (may include port, e.g. "vanity.interna:443")
// token  - Access token
function Vanity(options) {
  if (options) {
    this.host = options.host;
    this.token = options.token;
  }
  // We emit this error when we can't make send a request, but we don't want
  // the default behavior of uncaught exception to kill Node.
  this.on("error", function() { });
}

Util.inherits(Vanity, Events.EventEmitter);




// -- Activity stream ---


// Add activity to the activity stream.
//
// Activity argument consists of:
// id       - Unique activity identifier.  Optional.
// actor    - Activity actor is either a name (string) or an object.
// verb     - Activity performed.
// object   - Object associated with the activity, either display name (string)
//            or an object.  Optional. 
// location - Location name.  Optional.
// label    - Labels.  Optional.
//
// Actor may specify id and/or displayName, and optionally also url (to
// profile) and image.  If you don't have a displayName, just pass the id, and
// Vanity will make up a name for you.  If you only have the display name, you
// can pass it directly as a string argument.
//
// Object may specify url and/or displayName, and optionally also an image.  If
// you don't have a displayName, url will be shown as the object descriptor.
// If you only have the display name, you can pass it directly as a string
// argument.
//
// Image must specify url and may specify height and width in pixels.
//
// For example:
//
//   vanity.activity({ actor: "Assaf", verb: "shared", object: "http://bit.ly/GLUa9S" })
//
//   vanity.activity({
//     actor: {
//       id: "assaf",
//       displayName: "Assaf",
//       url: "http://labnotes.org/"
//     },
//     verb: "shared",
//     object: {
//       displayName: "hjkl",
//       url: "http://t.co/dKh54pQK",
//       image: {
//         url: "http://bit.ly/yq14vJ"
//       }
//     },
//     location: "San Francisco, CA",
//     labels: ["funny"]
//   })
Vanity.prototype.activity = function(activity) {
  // Ignore unless configured to connect to a server.
  if (!this.host || !this.token)
    return;

  // Actor/object can be a string, in which case they are the display name.
  var self   = this,
      actor  = activity.actor,
      object = activity.object;
  if (typeof actor == "string" || actor instanceof String)
    actor = { displayName: actor }
  if (typeof object == "string" || object instanceof String)
    object = { displayName: object }
  // Don't change activity object passed from caller, create a new one.
  var params = {
        id:       activity.id,
        actor:    actor,
        verb:     activity.verb,
        object:   object,
        location: activity.location,
        labels:   activity.labels
      };
  try {
    Request.post({ url: "http://" + this.host + "/v1/activity", json: params }, function(error, response, body) {
      if (error)
        self.emit("error", error);
      else if (response && response.statusCode >= 400)
        self.emit("error", new Error("Server returned " + response.statusCode + ": " + body));
    })
  } catch (error) {
    self.emit("error", error);
  }
}




// -- Split test --


// Returns a split test (SplitTest).
//
// Arguments are:
// id - Test identifier (alphanumeric/underscore/hyphen)
//
// Returns a SplitTest object.
Vanity.prototype.split = function(id) {
  // Caching.
  this.splits = this.splits || {};
  var test = this.splits[id];
  if (!test) {
    test = new SplitTest(this, id);
    this.splits[id] = test;
  }
  return test;
}


// Use vanity.split() to create this.
function SplitTest(vanity, id) {
  if (!id || !/^[\w\-]+$/.test(id))
    throw new Error("Split test identifier may only contain alphanumeric, underscore and hyphen");
  this.id = id;
  this.vanity = vanity;
  this.baseUrl = "http://" + vanity.host + "/v1/split/" + id;

  // Calculating an alternative is cheap, so we don't bother caching it.  But
  // there are two cases where we do want to cache.
  //
  // One is when an alternative is set explicitly by this client, we want to
  // return the same value consistently.
  //
  // Two is when an alternative is set explicitly by some other client (or the
  // server), and we get that value back (409 Conflict).
  this._cache = {};

  return this;
}


// Use this when choosing which alternative to show.
//
// If you want Vanity to pick up which alternative to show, call with one
// argument (participant identifier) and it will return an alternative number.
// This request updates the server but returns immediately without waiting for
// response.
//
// Example:
//   if (split.show(userId))
//     render("optionB"); // Alternative 1 that we're testing
//   else
//     render("optionA"); // Alternative 0, our base line
//
// You can also call with participant and callback.  This will contact the
// server, wait for response, and return the actual alternative number.  This is
// the safest way to get the alternative.
//
// Example:
//
//   split.show(userId, function(error, alternative) {
//     if (alternative)
//       render("optionB"); // Alternative 1 that we're testing
//     else
//       render("optionA"); // Alternative 0, our base line
//   })
//
// You can also force a particular alternative by calling with participant,
// alternative number and optional callback.  Note that an alternative can be
// set only once.  With a callback, you'll get the alternative stored on the
// server, which may differ from the one passed as argument.
//
// Example:
//
//   // These users always sees the second option
//   if (user.beta)
//     split.show(userId, 1);
//   split.show(userId, function(error, alternative) {
//     . . .
//   })
SplitTest.prototype.show = function(participant, alternative, callback) {
  // Request only sets the alternative.
  var vanity = this.vanity,
      cache  = this._cache,
      cached = cache[participant],
      params;

  // Yes we do get errors from the server for all these cases, but not all
  // requests wait for a response, and better fail fast.
  if (typeof(participant) != "string" && !(participant instanceof String) &&
      typeof(participant) != "number" && !(participant instanceof Number))
    throw new Error("Expecting participant to be identifier (string or number)");

  if (arguments.length == 2 && typeof(alternative) == "function") {
    callback = alternative;
    alternative = (cached == undefined ? this.alternative(participant) : cached);
  } else if (arguments.length == 1) {
    alternative = (cached == undefined ? this.alternative(participant) : cached);
  } else {
    alternative = (alternative ? 1 : 0);
    // If alternative was specified by caller, we want to return it next time
    // around without the network call, so we cache the result passed here.
    if (cached == undefined)
      cache[participant] = alternative;
    else
      alternative = cached;
  }

  if (callback && !typeof(callback) == "function")
    throw new Error("Expecting callback to be a function");

  // Ignore unless configured to connect to a server.
  if (!vanity.host || !vanity.token) {
    if (callback)
      process.nextTick(function() {
        callback(null, alternative);
      });
    return;
  }

  params = { alternative: alternative };
  Request.post({ url: this.baseUrl + "/" + participant, json: params }, function(error, response, body) {
    var actual;
    if (!error && response.statusCode >= 400)
      error = new Error("Server returned " + response.statusCode + ": " + body);
    if (error)
      vanity.emit("error", error)
    else if (response.statusCode == 200) {
      actual = body.alternative;
      if (actual != alternative) {
        cache[participant] = actual;
        vanity.emit("conflict", { participant: participant, alternative: actual, conflict: alternative });
      }
    } else // No response from server (404, 500, etc)
      actual = alternative;
    if (callback)
      callback(error, actual)
  });
  if (!callback)
    return alternative;
}


// Use this to record conversion (goal completion).
//
// Example:
//   split.completed(userId)
//
// If you want to wait for response from the server, pass a callback as the
// second argument.
//
// You can call this method multiple times for a given participant, only the
// first call has any affect.  You can call this method without first calling
// `show`, and it will also add the participant to the experiment.
SplitTest.prototype.completed = function(participant, callback) {
  var vanity = this.vanity;

  // Ignore unless configured to connect to a server.
  if (!vanity.host || !vanity.token) {
    if (callback)
      process.nextTick(callback);
    return;
  }

  // Yes we do get errors from the server for all these cases, but not all
  // requests wait for a response, and better fail fast.
  if (typeof(participant) != "string" && !(participant instanceof String) &&
      typeof(participant) != "number" && !(participant instanceof Number))
    throw new Error("Expecting participant to be identifier (string or number)");

  Request.post({ url: this.baseUrl + "/" + participant + "/completed" }, function(error, response, body) {
    // There are protocol errors (error) and server reported errors (4xx and
    // 5xx).
    if (!error && response.statusCode >= 400)
      error = new Error("Server returned " + response.statusCode + ": " + body);
    if (error)
      vanity.emit("error", error)
    if (callback)
      callback(error)
  })
}


// Retrieve all that is known about a participant.
//
// Arguments are:
// participant - Participant identifier
// callback    - Call with error and result (null if no participant)
//
// Result contains:
// participant - Participant identifier
// alternative - Alternative number
// joined      - When participant joined the test (Date)
// completed   - When participant completed the test (Date)
SplitTest.prototype.get = function(participant, callback) {
  // Ignore unless configured to connect to a server.
  if (!this.vanity.host || !this.vanity.token) {
    if (callback)
      process.nextTick(callback);
    return;
  }

  if (!callback)
    throw new Error("Expecting callback as last argument");
  Request.get({ url: this.baseUrl + "/" +participant }, function(error, response, body) {
    var result;
    if (!error && response.statusCode == 200) {
      result = JSON.parse(body);
      if (result.joined)
        result.joined = new Date(result.joined);
      if (result.completed)
        result.completed = new Date(result.completed);
    }
    callback(error, result);
  })
}


// Retrieve all that is known about a split test.
//
// Arguments are:
// participant - Participant identifier
// callback    - Call with error and result (null if no participant)
//
// Result contains:
// title       - Human friendly title
// created     - When this test was created (first participant)
// alternative - The two alternatives
SplitTest.prototype.stats = function(callback) {
  if (!callback)
    throw new Error("Expecting callback as last argument");

  // Ignore unless configured to connect to a server.
  if (!this.vanity.host || !this.vanity.token) {
    process.nextTick(function() {
      callback(new Error("Missing host or token"));
    });
    return;
  }

  Request.get({ url: this.baseUrl }, function(error, response, body) {
    if (!error && response.statusCode >= 400)
      error = new Error("Server returned " + response.statusCode + ": " + body);
    if (body) {
      var result = JSON.parse(body);
      result.created = new Date(result.created);
    }
    callback(error, result);
  })
}


// Return alternative number for the given participant.
//
// participant - Participant identifier
//
// Returns 0 or 1.
SplitTest.prototype.alternative = function(participant) {
  var hash = 0,
      char;
  for (var i = 0 ; i < participant.length ; ++i) {
    char = participant.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash // Convert to 32bit integer
  }
  hash = Math.abs(hash);
  return hash % 2;
}


module.exports = Vanity
