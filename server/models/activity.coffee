# Activity stream.
#
# Activity stream consists of multiple activities.


Crypto    = require("crypto")
search    = require("../config/search")
name      = require("../lib/vanity/names")
geocode   = require("../lib/vanity/utils/geocode")



class Activity

  # Creates a new activity.
  #
  # id        - Unique activity identifier.
  # actor     - The actor is an object with id, displayName, url and image.  Requires at least id or displayName.
  # verb      - Activity verb.
  # object    - If activity has an object, it may specify displayName, url and/or image.
  # location  - Optional and consists of displayName and lat, lon.
  # published - When activity was published (defaults to null).
  #
  # If no activity identifier is specified, one will be created based on the various activity fields.  If successfuly,
  # the callback includes the activity identifier.
  #
  # Returns the activity identifier immediately.  Passes error and id to callback after storing activity.
  #
  # If required fields are missing, throws an error.  Make sure to catch it, callback will not be called.
  @create: ({ id, published, actor, verb, object, location }, callback)->
    unless verb
      throw new Error("Activity requires verb")
    unless actor && (actor.displayName || actor.id)
      throw new Error("Activity requires actor")
    # Each activity has a timestamp, default to now.
    published ||= new Date()

    # If no activity specified, we use the activity content to create a unique ID.
    unless id
      sha = Crypto.createHash("SHA1")
      values = [
        actor && (actor.displayName || actor.id) || "anonymous",
        verb,
        object && (object.url || object.displayName) || "",
        published.toISOString()
      ].map((val)-> escape(val))
      id = sha.update(values.join(":")).digest("hex")

    doc =
      id: id.toString()
      actor:
        # If actor name is not specified, we can make one up based on actor ID.  This is used when you have an
        # anonymized activity stream, but still want to see related activities by same visitor.
        displayName:  (actor.displayName || name(actor.id)).toString()
        url:          actor.url?.toString()
        image:        actor.image
      verb: verb.toString()
      published: new Date(published).toISOString()

    # Some activities have an object.  An object must have display name and/or URL.  We show display name if we have
    # one, but we consider the activity unique based on object URL (see SHA above).
    if object && (object.displayName || object.url)
      doc.object =
        displayName: (object.displayName || object.url).toString()
        url:         object.url?.toString()
        image:       object.image

    # This in fact stores the document.  In Node callback world, we write functions backwards.
    store = ->
      options =
        create: false
        id:     id
      search (es_index)->
        es_index.index "activity", doc, options, (error)->
          callback error, id

    # If location provided we need some geocoding action.
    if location
      geocode location, (error, result)->
        # TODO: proper logging comes here
        if error then console.error error
        if result
          doc.location = result
        else
          doc.location = { displayName: location }
        store()
    else
      store()

    return id


  # Returns activity by id (null if not found).
  @get: (id, callback)->
    search (es_index)->
      es_index.get id, ignoreMissing: true, callback


  # Returns all activities that meet the search criteria.
  @search: (query, callback)->
    params =
      query:  query
      from:   0
      size:   10
      sort:   { published: "desc" }
    search (es_index)->
      es_index.search params, callback


  # Deletes activity by id.
  @delete: (id, callback)->
    search (es_index)->
      es_index.delete "activity", id, ignoreMissing: true, callback


module.exports = Activity
