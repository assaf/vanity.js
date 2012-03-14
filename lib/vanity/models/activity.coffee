Crypto = require("crypto")
{ Model } = require("poutine")
name = require("../name")



class Activity extends Model
  @collection "activities"

  @field "actor"
  @field "verb", String
  @field "object"
  @field "timestamp", Date

  @create = ({ id, timestamp, actor, verb, object }, callback)->
    throw new Error("Activity requires verb") unless verb
    throw new Error("Activity requires actor") unless actor && (actor.displayName || actor.id)
    # Each activity has a timestamp, default to now.
    timestamp ||= new Date()

    # If no activity specified, we use the activity content to create a unique ID.
    unless id
      sha = Crypto.createHash("SHA1")
      values = [
        actor && (actor.displayName || actor.id) || "anonymous",
        verb,
        object && (object.url || object.displayName) || "",
        timestamp.toISOString()
      ].map((val)-> escape(val))
      id = sha.update(values.join(":")).digest("hex")

    doc =
      _id: id
      actor:
        # If actor name is not specified, we can make one up based on actor ID.  This is used when you have an
        # anonymized activity stream, but still want to see related activities by same visitor.
        displayName:  actor.displayName || name(actor.id)
        url:          actor.url
        image:        actor.image
      verb: verb
      timestamp: timestamp

    # Some activities have an object.  An object must have display name and/or URL.  We show display name if we have
    # one, but we consider the activity unique based on object URL (see SHA above).
    if object && (object.displayName || object.url)
      doc.object =
        displayName: object.displayName || object.url
        url:         object.url
        image:       object.image?.url && object.image

    Activity.insert doc, callback



module.exports = Activity
