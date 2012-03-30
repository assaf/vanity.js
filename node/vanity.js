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
  if (!this.host && !this.token)
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
Vanity.prototype.split = function(id, alternatives) {
  // Caching.
  this.splits = this.splits || {};
  var test = this.splits[id];
  if (!test) {
    test = new SplitTest(this, id, alternatives);
    this.splits[id] = test;
  }
  return test;
}


// Use vanity.split() to create this.
function SplitTest(vanity, id, alternatives) {
  if (!id || !/^[\w\-]+$/.test(id))
    throw new Error("Split test identifier may only contain alphanumeric, underscore and hyphen");
  this.id = id;
  this.vanity = vanity;
  this.baseUrl = "http://" + vanity.host + "/v1/split/" + id + "/";
  // Fix me later.
  this.alternatives = 2;

  // Calculating an alternative is cheap, so we don't bother caching it.  But
  // there are two cases where we do want to cache.
  //
  // One is when an alternative is set explicitly by this client, we want to
  // return the same value consistently.
  //
  // Two is when an alternative is set explicitly by some other client (or the
  // server), and we get that value back (409 Conflict).
  this._cache = {};
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
  // Yes we do get errors from the server for all these cases, but not all
  // requests wait for a response, and better fail fast.
  if (typeof(participant) != "string" && !(participant instanceof String) &&
      typeof(participant) != "number" && !(participant instanceof Number))
    throw new Error("Expecting participant to be identifier (string or number)");

  var cached = this._cache[participant];
  if (arguments.length == 2 && typeof(alternative) == "function") {
    callback = alternative;
    alternative = (cached == undefined ? this.alternative(participant) : cached);
  } else if (arguments.length == 1) {
    alternative = (cached == undefined ? this.alternative(participant) : cached);
  } else {
    if (typeof(alternative) != "number" && !(alternative instanceof Number))
      throw new Error("Expecting alternative to be a number");
    else if (alternative < 0)
      throw new Error("Expecting alternative to be a positive value");
    else if (alternative != Math.floor(alternative))
      throw new Error("Expecting alternative to be a positive value");

    // If alternative was specified by caller, we want to return it next time
    // around without the network call, so we cache the result passed here.
    if (cached == undefined)
      this._cache[participant] = alternative;
    else
      alternative = cached;
  }

  if (callback && !typeof(callback) == "function")
    throw new Error("Expecting callback to be a function");

  // Request only sets the alternative.
  var vanity = this.vanity,
      cache  = this._cache,
      params = { alternative: alternative };
  Request.put({ url: this.baseUrl + participant, json: params }, function(error, response, body) {
    // There are protocol errors (error) and server reported errors (4xx and
    // 5xx).  409 is a special case, this just tells us the alternative has been
    // set before to a different value.  We don't surface that at the moment.
    if (!error && response.statusCode >= 400 && response.statusCode != 409)
      error = new Error("Server returned " + response.statusCode + ": " + body);
    if (response && response.statusCode == 409)
      cache[participant] = body.alternative;
    if (callback)
      callback(error, body && body.alternative)
    else if (error)
      vanity.emit("error", error)
    else if (response && response.statusCode == 409)
      vanity.emit("conflict", { participant: participant,
                                alternative: body.alternative,
                                conflict: alternative })
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
SplitTest.prototype.completed = function(participant, outcome, callback) {
  // Yes we do get errors from the server for all these cases, but not all
  // requests wait for a response, and better fail fast.
  if (typeof(participant) != "string" && !(participant instanceof String) &&
      typeof(participant) != "number" && !(participant instanceof Number))
    throw new Error("Expecting participant to be identifier (string or number)");

  if (arguments.length == 2 && typeof(outcome) == "function") {
    callback = outcome;
    outcome = 0;
  } else if (arguments.length == 1)
    outcome = 0;
  else if (typeof(outcome) != "number" && !(outcome instanceof Number))
    throw new Error("Expecting outcome to be a number");
  
  var cached = this._cache[participant],
      vanity = this.vanity,
      params = {
        alternative: (cached == undefined ? this.alternative(participant) : cached),
        outcome:     outcome
      };
  Request.put({ url: this.baseUrl + participant, json: params }, function(error, response, body) {
    // There are protocol errors (error) and server reported errors (4xx and
    // 5xx).
    if (!error && response.statusCode >= 400)
      error = new Error("Server returned " + response.statusCode + ": " + body);
    if (callback)
      callback(error, body && body.outcome)
    else if (error)
      vanity.emit("error", error)
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
// outcome     - Outcome
// completed   - When participant completed the test (Date)
SplitTest.prototype.get = function(participant, callback) {
  if (!callback)
    throw new Error("Expecting callback as last argument");
  Request.get({ url: this.baseUrl + participant }, function(error, _, body) {
    var result;
    if (body) {
      result = JSON.parse(body);
      if (result.joined)
        result.joined = new Date(result.joined);
      if (result.completed)
        result.completed = new Date(result.completed);
    }
    callback(error, result);
  })
}


// Return alternative number for the given participant.
//
// participant - Participant identifier
//
// Returns alternative number between 0 and number of alternatives in this test
// (exclusive).
SplitTest.prototype.alternative = function(participant) {
  var hash = 0,
      char;
  for (var i = 0 ; i < participant.length ; ++i) {
    char = participant.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash // Convert to 32bit integer
  }
  hash = Math.abs(hash);
  return hash % this.alternatives;
}


module.exports = Vanity
