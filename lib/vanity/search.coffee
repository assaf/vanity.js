# Manages ElasticSearch index and client.
#
# We use ElasticSearch for activity stream, since it allows us to perform all kinds of fancy queries and is generally
# blazing fast.  Most of this module can be boiled down to two methods:
#
# * `Search.initialize` - Call this once to initialize the index and load the mappings.  After the callback returns with
#    no errors, you'll be able to use Search.index.
# * `Search.index` - Elastical.Index object that provides access to the index use by Vanity.  Only available after
#    successful completion of Search.initialize.
#
# The configuration options are:
# * index    - Index name ("vanity")
# * hostname - Host name ("localhost")
# * port     - Port number (9200)
#
# When run with `NODE_ENV=test`, the `Search.initialize` method will delete the index first and then create a new one.


Elastical = require("elastical")
config    = require("./config")


Search =
  # Configuration object, loaded from master configuration, but you can change this before calling initialize.
  config: config.elasticsearch

  # An Elastical.Index object referencing the Vanity search index.  Only available after successful callback from
  # Search.initialize.
  index: "did you forget to call Search.initialize?"

  # Apply this mappings when creating the index.
  mappings:
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

  # Call this at startup to initialize the search index.
  initialize: (callback)->
    index_name = Search.config.index || "vanity"
    client = new Elastical.Client(Search.config.hostname || "localhost",
                                  port: Search.config.port,
                                  curlDebug: process.env.DEBUG)
    index = new Elastical.Index(client, index_name)
    createIndex = (callback)->
      options =
        settings: {}
        mappings: Search.mappings
      client.createIndex index_name, options, (error)->
        unless error
          Search.index = index
        callback(error, index)

    if process.env.NODE_ENV == "test"
      # When testing, make sure to delete and re-create index for each run
      index.deleteIndex ->
        createIndex(callback)
    else
      index.exists index_name, (error, exists)->
        if exists
          Search.index = index
          callback(null, index)
        else
          createIndex(callback)


module.exports = Search
