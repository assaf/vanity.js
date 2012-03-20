# Access to ElasticSearch vanity index.
#
# We use ElasticSearch for activity stream, since it allows us to perform all kinds of fancy queries and is generally
# blazing fast.
#
# This module exports a function that provides the caller with an Elastical.Index object that can access the vanity
# search index.
#
# Example:
#
#   search = require("config/search")
#
#   search (index)->
#     index.get id, (error, document)->
#       console.log "Loaded #{document}"
#
# The configuration options are:
# * index    - Index name ("vanity")
# * hostname - Host name ("localhost")
# * port     - Port number (9200)
#
# When run with `NODE_ENV=test`, the index is deleted first and then re-created.


Elastical = require("elastical")
config    = require("./index")


# Apply this mappings when creating the index.
MAPPINGS =
  activities:
    properties:
      id:
        type: "string"
        index: "not_analyzed"
      actor:
        type: "object"
        properties:
          id:
            type: "string"
            index: "not_analyzed"
          displayName:
            type: "string"
          url:
            type: "string"
          image:
            type: "object"
            index: "no"
      verb:
        type: "string"
      object:
        type: "object"
        properties:
          id:
            type: "string"
            index: "not_analyzed"
          displayName:
            type: "string"
          url:
            type: "string"
          image:
            type: "object"
            index: "no"
      labels:
        type: "string"
      location:
        type: "geo_point"
        lat_lon: true
      published:
        type: "date"
      content:
        type: "string"
        index: "no"


# Eventually set to Elastical.Index object.
es_index = null
# Queue of functions waiting for es_index to be set.
waiting = null

# This method calls function with an Elastical.Index object.  But first, it will make sure the vanity index exists,
# creating it if necessary.
search = (fn)->
  # Vanity index exists, pass it to function.
  if es_index
    fn es_index
    return

  # Queue waiting for ES index to get initialized, add to end of queue.
  if waiting
    waiting.push fn
    return

  # Create a queye waiting for ES index to get initialized, add to end of queue.
  waiting = [fn]

  # Use configuration to create es_index, but don't make it accessible yet.
  index_name = config.elasticsearch?.index || "vanity"
  client = new Elastical.Client(config.elasticsearch?.hostname || "localhost",
                                port: config.elasticsearch?.port,
                                curlDebug: process.env.DEBUG)
  index = new Elastical.Index(client, index_name)

  # Tell ES to create the index with the supplied mappings.
  createIndex = (callback)->
    options =
      settings: {}
      mappings: MAPPINGS
    client.createIndex index_name, options, (error)->
      # If we can't connect/use ES, we just kill the process.
      if error
        throw error
      complete()

  # Make the Elastical.Index client available to future callers, and then call all waiting functions (FIFO).
  complete = ->
    es_index = index
    for fn in waiting
      do (fn)->
        process.nextTick ->
          fn index
    waiting = null

  if process.env.NODE_ENV == "test"
    # We get here when running tests: always delete the index and then re-create it, so each test run uses a fresh
    # index.
    index.deleteIndex ->
      createIndex()
  else
    # Check if index already exists before trying to create new one.
    index.exists index_name, (error, exists)->
      if exists
        complete()
      else
        createIndex()

  # This function never returns anything
  return


# This is used during testing to delete index between tests.
search.teardown = (callback)->
  if es_index
    es_index.deleteIndex ->
      es_index = null
      callback()
  else
    callback()


module.exports = search
