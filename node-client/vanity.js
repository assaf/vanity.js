/**
 * Exports constructor for a Vanity client.
 *
 * Exmple:
 *   var Vanity = require("vanity"),
 *       vanity = new Vanity("vanity.internal:443", "secret token");
 *
 *   vanity.activity({ actor: "Assaf", verb: "shared", object: "http://bit.ly/GLUa9S" })
 */

var request = require("request"),
    util    = require("util"),
    events  = require("events");


/**
 * Constructs a new Vanity client.  Options are:
 * host   - Host name of vanity server (may include port, e.g. "vanity.interna:443")
 * token  - Access token
 */
function Vanity(options) {
  if (options) {
    this.host = options.host;
    this.token = options.token;
  }
  // We emit this error when we can't make send a request, but we don't want
  // the default behavior of uncaught exception to kill Node.
  this.on("error", function() { });
}

util.inherits(Vanity, events.EventEmitter);



/**
 * Add activity to the activity stream.
 *
 * Activity argument consists of:
 * id       - Unique activity identifier.  Optional.
 * actor    - Activity actor is either a name (string) or an object.
 * verb     - Activity performed.
 * object   - Object associated with the activity, either display name (string)
 *            or an object.  Optional. 
 * location - Location name.  Optional.
 * label    - Labels.  Optional.
 *
 * Actor may specify id and/or displayName, and optionally also url (to
 * profile) and image.  If you don't have a displayName, just pass the id, and
 * Vanity will make up a name for you.  If you only have the display name, you
 * can pass it directly as a string argument.
 *
 * Object may specify url and/or displayName, and optionally also an image.  If
 * you don't have a displayName, url will be shown as the object descriptor.
 * If you only have the display name, you can pass it directly as a string
 * argument.
 *
 * Image must specify url and may specify height and width in pixels.
 *
 * For example:
 *
 *   vanity.activity({ actor: "Assaf", verb: "shared", object: "http://bit.ly/GLUa9S" })
 *
 *   vanity.activity({
 *     actor: {
 *       id: "assaf",
 *       displayName: "Assaf",
 *       url: "http://labnotes.org/"
 *     },
 *     verb: "shared",
 *     object: {
 *       displayName: "hjkl",
 *       url: "http://t.co/dKh54pQK",
 *       image: {
 *         url: "http://bit.ly/yq14vJ"
 *       }
 *     },
 *     location: "San Francisco, CA",
 *     labels: ["funny"]
 *   })
 */
Vanity.prototype.activity = function(activity) {
  // Ignore unless configured to connect to a server.
  if (!this.host && !this.token)
    return;
  // Actor/object can be a string, in which case they are the display name.
  var self = this,
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
    request.post({ url: "http://" + this.host + "/v1/activity", json: params }, function(error, response, body) {
      if (error)
        self.emit("error", error);
      else if (response.statusCode >= 400)
        self.emit("error", "Server returned " + response.statusCode + ": " + body);
    })
  } catch (error) {
    self.emit("error", error);
  }
}


module.exports = Vanity
