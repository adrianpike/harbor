http = require 'http'
net = require 'net'
{StringDecoder} = require 'string_decoder'

class Proxy
  successes: 0
  errors: 0
  connections: 0

  constructor: (@port, @service, @backend) ->
    console.log "Proxying: #{@port} --> #{@service}"
    @server = net.createServer()
    @server.on 'error', (err) ->
      # TODO: shut down or something. :)
      console.error err

    @server.listen @port, (err) ->
      console.error err if err

    @server.on 'connection', (sock) =>
      decoder = new StringDecoder

      discoverHeader = =>
        return if sock.destroyed

        # Let's try and find a header.
        rawHeaders = ''
        headers = {}
        while chunk = sock.read()
          chunkString = decoder.write chunk
          rawHeaders += chunkString
          if rawHeaders.match /\r\n\r\n/m
            headers = @decodeHeaders rawHeaders

        @getRevision headers, (err, revision) =>
          return @fatalError sock, headers if err or not revision
          console.log "Routing to revision #{revision}"
          @getBackend @service, revision, (err, backend) =>
            return @fatalError sock, headers if err or not backend?.host
            console.log "Routing to backend #{backend.host}"
            sock.removeListener 'readable', discoverHeader
            sock.unshift new Buffer rawHeaders, 'utf8'
            @routeToBackend sock, backend

      sock.on 'readable', discoverHeader

  getRevision: (headers, callback) ->
    return callback null, headers['Revision'] if headers['Revision']
    @backend.domainRevisions (err, domains) ->
      host = headers['Host'] or 'default'
      callback err, domains?[host]

  getBackend: (service, revision, callback) ->
    # TODO: Least-connections? Round-robin? Random?
    @backend.backendsForServiceAndDeploy service, revision, (err, backends) ->
      callback null,
        service: service
        revision: revision
        host: backends[0]

  decodeHeaders: (rawHeaders) ->
    {}

  shutdown: ->
    # NOOP for now

  routeToBackend: (sock, backend) ->
    [upstreamHost, upstreamPort] = backend.host.split ':'
    upstreamSocket = net.createConnection upstreamPort, upstreamHost
    sock.pipe upstreamSocket
    upstreamSocket.pipe sock

    upstreamSocket.on 'error', (err) =>
      # If ECONNREFUSED - pull this backend out of the rotation.
      # Can retry at this point.
      if err.code is 'ECONNREFUSED'
        # TODO: retry
        @backend.removeBackend backend.service, backend.revision, backend.host, ->
      console.log err
      @fatalError sock

    sock.on 'error', (err) ->
      # This is a client problem, not ours. We don't have to worry.
      upstreamSocket.end()

    upstreamSocket.on 'end', sock.end
    sock.on 'end', upstreamSocket.end

  fatalError: (sock, failureType, headers = {}) ->
    sock.unpipe()
    sock.end 'Backends unavailable at this time.\n\n'

module.exports = Proxy
