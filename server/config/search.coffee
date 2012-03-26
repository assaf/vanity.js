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


# Eventually set to Elastical.Index object.
es_index = null

# This method calls function with an Elastical.Index object.  But first, it will make sure the vanity index exists,
# creating it if necessary.
search = (fn)->
  # Vanity index exists, pass it to function.
  if es_index
    fn es_index
    return

  # Use configuration to create es_index, but don't make it accessible yet.
  index_name = config.elasticsearch?.index || "vanity"
  client = new Elastical.Client(config.elasticsearch?.hostname || "localhost",
                                port: config.elasticsearch?.port,
                                curlDebug: process.env.DEBUG)
  index = new Elastical.Index(client, index_name)

  # Tell ES to create the index with the supplied mappings.
  createIndex = (callback)->
    Activity  = require("../models/activity") # avoid circular dependencies
    options =
      settings: {}
      mappings: { activities: Activity.MAPPINGS }
    setTimeout ->
    client.createIndex index_name, options, (error)->
      # If we can't connect/use ES, we just kill the process.
      if error
        throw error
      else
        # Give ElasticSearch some time to sort itself before proceeding
        es_index = index
        fn(es_index)

  if process.env.NODE_ENV == "test"
    # We get here when running tests: always delete the index and then re-create it, so each test run uses a fresh
    # index.
    index.deleteIndex ->
      createIndex()
  else
    # Check if index already exists before trying to create new one.
    index.exists (error, exists)->
      if exists
        es_index = index
        fn(es_index)
      else
        createIndex()

  # This function never returns anything
  return


# Returns Elastical.Index object.
get_index = ->
  # Use configuration to create es_index, but don't make it accessible yet.
  index_name = config.elasticsearch?.index || "vanity"
  client = new Elastical.Client(config.elasticsearch?.hostname || "localhost",
                                port: config.elasticsearch?.port,
                                curlDebug: process.env.DEBUG)
  return new Elastical.Index(client, index_name)


# This is used during testing to delete index between tests.
search.teardown = (callback)->
  index = get_index()
  es_index = null
  index.exists (error, exists)->
    if exists
      index.deleteIndex callback
    else
      callback()


module.exports = search
