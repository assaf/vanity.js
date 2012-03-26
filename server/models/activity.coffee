# Activity stream.
#
# Activity stream consists of multiple activities.  Each activity has:
# id        - Unique activity identifier.
# actor     - Activity actor is an object with id, displayName, url and image.
# verb      - Activity verb.
# object    - Activity object has displayName, url and image.  Optional.
# location  - Consists of displayName and lat, lon.  Optional.
# published - When activity was published.
# labels    - Array of labels.
 

Crypto            = require("crypto")
{ EventEmitter }  = require("events")
Elastical         = require("elastical")
Express           = require("express")
URL               = require("url")
config            = require("../config")
server            = require("../config/server")
name              = require("../lib/names")
geocode           = require("../lib/geocode")


# For dispatching events, e.g. notify activity got created.
events = new EventEmitter()


PROTOCOLS = ["http:", "https:", "mailto:"]

# Parse and return URL.  Throws error if URL is not valid or contains unsupported protocol (e.g. javascript:).
sanitizeUrl = (url)->
  return undefined unless url
  url = URL.parse(url, false, true)
  unless ~PROTOCOLS.indexOf(url.protocol)
    throw new Error("Only http/s and mailto URLs supported")
  return URL.format(url)

# Sanitizes the image object, returning one that has sanitized URL and wight/height numbers.  May return undefined.
sanitizeImage = (image)->
  return undefined unless image && image.url
  result = url: sanitizeUrl(image.url)
  result.width = parseInt(image.width, 10) if image.width
  result.height = parseInt(image.height, 10) if image.height
  return result


Activity =

  # ElasticSearch index mapping for activities.
  MAPPINGS:
    properties:
      id:
        type: "string"
        index: "not_analyzed"
        include_in_all: false
      actor:
        type: "object"
        path: "just_name"
        include_in_all: false
        properties:
          id:
            type: "string"
            index: "not_analyzed"
            index_name: "actor_id"
          displayName:
            type: "string"
            index_name: "actor"
          url:
            type: "string"
            index_name: "actor_url"
          image:
            type: "object"
      verb:
        type: "string"
        include_in_all: false
      object:
        type: "object"
        path: "just_name"
        include_in_all: false
        properties:
          id:
            type: "string"
            index: "not_analyzed"
            index_name: "object_id"
          displayName:
            type: "string"
            index_name: "object"
          url:
            type: "string"
            index_name: "object_url"
          image:
            type: "object"
      labels:
        type: "string"
        include_in_all: true
      location:
        type: "geo_point"
        lat_lon: true
        properties:
          displayName:
            type: "string"
            index_name: "location"
            include_in_all: true
      title:
        type: "string"
        index: "no"
        include_in_all: true
      content:
        type: "string"
        index: "no"
        include_in_all: false
      published:
        type: "date"
    _timestamp:
      enabled: true
      path:    "published"


  # -- Creating and deleting --

  # Creates a new activity.
  #
  # id        - Unique activity identifier.
  # actor     - The actor is an object with id, displayName, url and image.  Requires at least id or displayName.
  # verb      - Activity verb.
  # object    - If activity has an object, it may specify displayName, url and/or image.
  # location  - Optional and consists of displayName and lat, lon.
  # published - When activity was published (defaults to null).
  # labels    - Array of labels.
  #
  # If no activity identifier is specified, one will be created based on the various activity fields.  If successfuly,
  # the callback includes the activity identifier.
  #
  # Returns the activity identifier immediately.  Passes error and id to callback after storing activity.
  #
  # If required fields are missing, throws an error.  Make sure to catch it, callback will not be called.
  create: ({ id, published, actor, verb, object, location, labels }, callback)->
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
        id:           actor.id
        displayName:  actor.displayName || name(actor.id)
        url:          sanitizeUrl(actor.url)
        image:        sanitizeImage(actor.image)
      verb: verb.toString()
      published: new Date(published).toISOString()

    if labels
      doc.labels = labels.map((label)-> label.toString())

    # Some activities have an object.  An object must have display name and/or URL.  We show display name if we have
    # one, but we consider the activity unique based on object URL (see SHA above).
    if object && (object.displayName || object.url)
      doc.object =
        displayName: object.displayName || sanitizeUrl(object.url)
        url:         sanitizeUrl(object.url)
        image:       sanitizeImage(object.image)

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
        if error
          console.error error
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
    Activity.index().index "activity", doc, options, (error)->
      if error
        Activity.emit "error", error
      else
        Activity.emit "activity", doc
      if callback
        callback error, doc?.id


  # Deletes activity by id.
  delete: (id, callback)->
    Activity.index().delete "activity", id, ignoreMissing: true, callback


  # -- Retrieving and searching --


  # Returns activity by id (null if not found).
  get: (id, callback)->
    Activity.index().get id, ignoreMissing: true, (error, activity)->
      if activity
        activity.url = "/activity/#{activity.id}"
        activity.labels ||= []
      callback(error, activity)


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
      sort:   { published: { order: "desc" } }
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
    Activity.index().search params, (error, results)->
      if error
        callback error
      else
        activities = results.hits.map((hit)->
          activity = hit._source
          activity.url = "/activity/#{activity.id}"
          activity.labels ||= []
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
    Activity.index().search params, (error, results)->
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


  # -- Index management --
 
  # Returns Elastical.Client for the search index.
  index: ->
    unless Activity._index
      name = config.elasticsearch?.index || "vanity"
      client = new Elastical.Client(config.elasticsearch?.hostname || "localhost",
                                    port: config.elasticsearch?.port,
                                    curlDebug: process.env.DEBUG)
      Activity._index = new Elastical.Index(client, name)
    return Activity._index

  # Create index if doesn't already exist.
  createIndex: (callback)->
    # Check if index already exists before trying to create new one.
    elastical = Activity.index()
    elastical.exists (error, exists)->
      if error
        callback(error)
      else if exists
        callback()
      else
        # Tell ES to create the index with the supplied mappings.
        options =
          settings: {}
          mappings: { activities: Activity.MAPPINGS }
        elastical.client.createIndex elastical.name, options, (error)->
          # If we can't connect/use ES, we just kill the process.
          if error
            throw error
          else
            callback()
    return

  # Deletes the index.  We use this during testing.
  deleteIndex: (callback)->
    elastical = Activity.index()
    elastical.exists (error, exists)->
      if exists
        elastical.deleteIndex(callback)
      else
        callback()
    return


module.exports = Activity
