# Geocodes free-form location.
#
# Exports a single method that geocodes a string.  If successul, passes one result to callback consisting of:
# * displayName - Canonical form of location
# * lat         - Latitude
# * lon         - Longitude


QS      = require("querystring")
request = require("request")


# How long to wait for Google API response (in ms).
TIMEOUT = 500

# Map result from Google API into suitable format for storing in ElasticSearch.
# Google uses lat/lng, ElasticSearch uses lat/lon.
map_result = (result)->
  return displayName: result.formatted_address, lat: result.geometry.location.lat, lon: result.geometry.location.lng


# Geocodes free-form location string.
geocode = (location, callback)->
  url = "http://maps.googleapis.com/maps/api/geocode/json?" + QS.stringify(address: location, sensor: false)
  request url: url, timeout: TIMEOUT, (error, response, body)->
    if error
      callback error
      return

    # This will fail on any error status code, and also if we get back HTML page instead of JSON object.  APIs are full
    # of surprises.
    if response.statusCode == 200 && /^application\/json/.test(response.headers["content-type"])
      data = JSON.parse(body)
      if data.status == "OK"
        callback null, map_result(data.results[0])
      else if data.status == "ZERO_RESULTS"
        callback null
      else
        # Over limit, but could be some other error code.
        callback new Error(data.status)
    else
      callback new Error("#{response.statusCode}: #{body.truncate(50)}")
  return


module.exports = geocode
