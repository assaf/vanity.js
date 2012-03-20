# Server-sent events EventSource
#
# See http://dev.w3.org/html5/eventsource/


{ EventEmitter }  = require("events")
Net               = require("net")
URL               = require("url")


class MessageEvent


# W3C DOM EventSource
class EventSource
  @CONNECTING: 0
  @OPEN: 1
  @CLOSED: 2

  constructor: (@url)->
    @readyState = EventSource.CONNECTING
    @_lastEventId = null
    @_reconnect = 500
    @_handlers = {}
    @_connect()

  close: ->
    if @_client
      @_client.end()
      @_client = null
    if @readyState != EventSource.CLOSED
      @readyState = EventSource.CLOSED

  # Event listener.
  onmessage: null

  # Event listener.
  onopen: null

  # Event listener.
  onerror: null

  # Adds event listener for the specified event type.
  addEventListener: (event, handler)->
    handlers = @_handlers[event] ||= []
    handlers.push handler unless ~handlers.indexOf(handler)
    return

  # Removes event listener from the specified event type.
  removeEventListener: (event, handler)->
    if handlers = @_handlers[event]
      handlers.remove handler
    return

  _connect: ->
    # Open connection to Web server and send request.
    url = URL.parse(@url)
    client = Net.connect(url.port, url.post)
    client.setNoDelay(true)
    client.on "connect", =>
      @_client = client
      # HTTP GET request with minimum necessary headers, including ID of last event.
      client.setEncoding "utf-8"
      request = "GET #{url.path} HTTP/1.1\r\nHost: #{url.hostname}\r\nAccept: text/event-stream\r\n"
      if @_lastEventId
        request += "Last-Event-ID: #{@_lastEventId}\r\n"
      client.write request + "\r\n"

      # Process the response.  We expect this to be the header, but may also hold some body chunks.
      client.once "data", (chunk)=>
        [header, body] = chunk.split(/\r\n\r\n/)
        # Split header into lines, top line contains protocol and status
        header_lines = header.split(/\r\n/)
        status_line = header_lines.shift()
        status_code = parseInt(status_line.match(/^HTTP\/\d\.\d (\d{3})/)[1], 10)
        headers = header_lines.reduce((headers, line)->
          [_, name, value] = line.match(/([^:]+):\s+(.*)$/)
          headers[name.toLowerCase()] = value
          return headers
        , {})
        # We need to determine if response is chunked.
        @_chunked = headers["transfer-encoding"] == "chunked"

        # If the status code is not 200, send error and we're done
        if status_code == 200
          # Announce the connection and set up event handlers to listen for data, errors and closing. 
          @_announce()
          client.on "data", @_data.bind(this)
          client.on "end", =>
            @_flush()
            @_reopen()
          client.on "error", @_error.bind(this)
          # If we picked some body chunks with the header, have them processed next.
          client.emit "data", body unless body == ""
        else
          @_error new Error("Status code #{status_code}")
          return

  # "When a user agent is to announce the connection, the user agent must queue a task which, if the readyState
  # attribute is set to a value other than CLOSED, sets the readyState attribute to OPEN and fires a simple event named
  # open at the EventSource object."
  _announce: ->
    if @readyState != EventSource.CLOSED
      @readyState = EventSource.OPEN
    if @onopen
      process.nextTick @onopen

  # This part deals with chunked transfer encoding and assembles the chunks back into a buffered message, from which we
  # can parse the event stream.  It receives each packet/buffer from Net.Client.
  _data: (chunk)->
    if @_chunked
      @_chunked_buffer ||= ""
      @_chunked_buffer += chunk
      # Chunked transfer has chunk size followed by chunk itself.
      while match = @_chunked_buffer.match(/()^[0-9a-fA-F]+\r\n/)
        size = parseInt(match[0], 16)
        prefix = match[0].length
        if @_chunked_buffer.length >= prefix + size + 2
          chunk = @_chunked_buffer.slice(prefix, prefix + size)
          @_chunked_buffer = @_chunked_buffer.slice(prefix + size + 2)
          @_chunk chunk
    else
      @_chunk chunk

  # This part receives chunks, pulls them together and then splits them up into events based on the empty line boundary.
  _chunk: (chunk)->
    @_parse_buffer ||= ""
    @_parse_buffer += chunk
    # This is of course not super smart, but works well enough for chunked.
    events = chunk.split(/\r\n\r\n|\r\r|\n\n/)
    if events.length > 0
      # Process all but the last part
      @_parse_buffer = events[events.length - 1]
      for event in events
        @_parse event

  # The last event may not be followed by an empty line, this method is used to process it.
  _flush: ->
    if @_parse_buffer
      @_parse @_parse_buffer
      @_parse_buffer = null

  # Given a set of lines that make up an event, parse and process it.
  _parse: (event)->
    name = null
    data = ""

    lines = event.split(/\r\n|\r|\n/)
    for line in lines
      [_, field, _, value] = line.match(/^([^:]*)(:\s?)?(.*)$/)
      switch field
        when "event"
          name = value
        when "data"
          data += "#{value || ""}\n"
        when "id"
          @_lastEventId = value || ""

    unless data
      return
    if data[data.length - 1] == "\n"
      data = data.slice(0, data.length - 1)
    # Create and dispatch event
    event = new MessageEvent()
    event.type = name || "message"
    event.data = data
    event.origin = @url
    event.lastEventId = @_lastEventId

    if @onmessage
      process.nextTick =>
        @onmessage event
    if handlers = @_handlers[event.type]
      for handler in handlers
        process.nextTick ->
          handler event

  # "When a user agent is to fail the connection, the user agent must queue a task which, if the readyState attribute is
  # set to a value other than CLOSED, sets the readyState attribute to CLOSED and fires a simple event named error at
  # the EventSource object. Once the user agent has failed the connection, it does not attempt to reconnect!"
  _error: ->
    @close()
    if @onerror
      process.nextTick @onerror

  _reopen: ->
    # Not implemented at the moment.


module.exports = EventSource
