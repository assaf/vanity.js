# Activity stream.
#
# Activity stream consists of multiple activities.


Crypto            = require("crypto")
{ EventEmitter }  = require("events")
Express           = require("express")
URL               = require("url")
search            = require("../config/search")
server            = require("../config/server")
name              = require("../lib/names")
geocode           = require("../lib/geocode")


# For dispatching events, e.g. notify activity got created.
events = new EventEmitter()


PROTOCOLS = ["http:", "https:", "mailto:"]

# Parse and return URL.  Throws error if URL is not valid or contains unsupported protocol (e.g. javascript:).
sanitize_url = (url)->
  return undefined unless url
  url = URL.parse(url, false, true)
  unless ~PROTOCOLS.indexOf(url.protocol)
    throw new Error("Only http/s and mailto URLs supported")
  return URL.format(url)

# Sanitizes the image object, returning one that has sanitized URL and wight/height numbers.  May return undefined.
sanitize_image = (image)->
  return undefined unless image && image.url
  result = url: sanitize_url(image.url)
  result.width = parseInt(image.width, 10) if image.width
  result.height = parseInt(image.height, 10) if image.height
  return result


Activity =

  # -- Creating and deleting --

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
  create: ({ id, published, actor, verb, object, location }, callback)->
    unless verb
      throw new Error("Activity requires verb")
    unless actor && (actor.displayName || actor.id)
      throw new Error("Activity requires actor")
    # Each activity has a timestamp, default to now.
    published = Date.create(published)

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
        displayName:  actor.displayName || name(actor.id)
        url:          sanitize_url(actor.url)
        image:        sanitize_image(actor.image)
      verb: verb.toString()
      published: new Date(published).toISOString()

    # Some activities have an object.  An object must have display name and/or URL.  We show display name if we have
    # one, but we consider the activity unique based on object URL (see SHA above).
    if object && (object.displayName || object.url)
      doc.object =
        displayName: object.displayName || sanitize_url(object.url)
        url:         sanitize_url(object.url)
        image:       sanitize_image(object.image)

    # Create title from actor verb object combination
    title = [doc.actor.displayName, doc.verb]
    if doc.object
      title.push doc.object.displayName
    doc.title = title.join(" ") + "."

    # Create content similar to title but with links.
    content =[]
    if doc.actor.url
      content.push "<a href=\"#{doc.actor.url}\">#{doc.actor.displayName}</a>"
    else
      content.push doc.actor.displayName
    content.push verb
    if doc.object?.url
      content.push "<a href=\"#{doc.object.url}\">#{doc.object.displayName}</a>"
    else if doc.object
      content.push doc.object.displayName
    doc.content = content.join(" ") + "."
    if doc.object?.image
      doc.content + "<img src=\"#{doc.object.image.url}\">"

    # If location provided we need some geocoding action.
    if location
      geocode location, (error, result)->
        # TODO: proper logging comes here
        if error then console.error error
        if result
          doc.location = result
        else
          doc.location = { displayName: location }
        Activity._store doc, callback
    else
      Activity._store doc, callback
    # Return known identifier, not activity.
    return id

  # Store valid activity in ES.
  _store: (doc, callback)->
    options =
      create: false
      id:     doc.id
    search (es_index)->
      es_index.index "activity", doc, options, (error)->
        if error
          Activity.emit "error", error
          callback error if callback
        else
          Activity.emit "activity", doc
          callback null, doc.id if callback


  # Deletes activity by id.
  delete: (id, callback)->
    search (es_index)->
      es_index.delete "activity", id, ignoreMissing: true, callback


  # -- Retrieving and searching --


  # Returns activity by id (null if not found).
  get: (id, callback)->
    search (es_index)->
      es_index.get id, ignoreMissing: true, (error, activity)->
        if activity
          activity.url = "/activity/#{activity.id}"
        callback error, activity


  # Returns all activities that meet the search criteria.
  #
  # Options are:
  # query  - Query string
  # limit  - Only return that many results (up to 250)
  # offset - Return results starting from this offset
  # start  - Activities published at/after the start time
  # end    - Activities published up to (excluding) the end time
  #
  # Callback receive error followed by object with:
  # total      - Total number of results matching query
  # limit      - Actual limit applied to query
  # activities - Activities matching query (up to limit)
  search: (options, callback)->
    params =
      query:
        query_string:
          query: options.query || "*"
      from:   options.offset || 0
      size:   Math.min(options.limit || 250, 250)
      sort:   { published: "desc" }
    # Only if specified
    params.from = options.offset if options.offset
    # Add filter for start/end time, if specified
    if options.start || options.end
      range =
        gte: options.start
        lt:  options.end
      params.query =
        filtered:
          query: params.query
          filter:
            range:
              published: range
    # And ... go!
    search (es_index)->
      es_index.search params, (error, results)->
        if error
          callback error
        else
          activities = results.hits.map((hit)->
            activity = hit._source
            activity.url = "/activity/#{activity.id}"
            return activity)
          callback null,
            total: results.total
            limit: params.size
            activities: activities


  frequency: (query, callback)->
    params =
      query:
        query_string:
          query: query || "*"
      size:   10000
      sort:   { published: "desc" }
      fields: ["published", "verb"]
    # And ... go!
    search (es_index)->
      es_index.search params, (error, results)->
        if error
          callback error
        else
          rows = results.hits.map((hit)-> { date: hit.fields.published, verb: hit.fields.verb })
          callback null, rows


  # -- Activity stream events --

  emit: (event, data)->
    events.emit event, data

  # Add event listener.
  on: (event, listener)->
    Activity.addListener event, listener

  # Add event listener.
  once: (event, listener)->
    events.once event, listener

  # Add event listener.
  addListener: (event, listener)->
    events.addListener event, listener

  # Remove event listener.
  removeListener: (event, listener)->
    events.removeListener event, listener


module.exports = Activity
