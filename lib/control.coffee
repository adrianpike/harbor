restify = require 'restify'
Process = require './process'

###
Provide a control and statistics interface for the harbor server.
###
#
# TODO: authentication!!1111
class Control
  constructor: (@server) ->
    @httpServer = restify.createServer
      name: 'harbor'
      version: '0.1.0'

    @httpServer.use restify.bodyParser()

    @httpServer.get '/', (req, res, next) ->
      res.send status: 'ok'
      next()

    @httpServer.get '/routes', (req, res, next) =>
      @server.backend.domainRevisions (err, domains = {}) ->
        domains['default'] or= 'undefined' # Just to help people along
        res.send domains
        next()

    @httpServer.put '/routes/:domain', (req, res, next) =>
      @server.backend.routeDomain req.params.domain, req.params.release, (err) ->
        res.send 'Routed'
        next()

    @httpServer.del '/routes/:domain', (req, res, next) =>
      @server.backend.unrouteDomain req.params.domain, (err) ->
        res.send 'Removed'
        next()

    @httpServer.get '/services', (req, res, next) =>
      res.send (for port, service of @server.ports
        service: service
        port: port
        )
      next()

    @httpServer.put '/services/:port', (req, res, next) =>
      @server.backend.registerPort req.params.port, req.params.service, (err) ->
        res.send 'Registered'
        next()

    @httpServer.del '/services/:port', (req, res, next) =>
      @server.backend.unregisterPort req.params.port, (err) ->
        res.send 'Unregistered'
        next()

    @httpServer.get '/deploys', (req, res, next) =>
      @server.backend.deploys (err, deploys) ->
        res.send deploys
        next()

    @httpServer.get '/deploys/:deploy', (req, res, next) =>
      @server.backend.servicesForDeploy req.params.deploy, (err, services) ->
        res.send services
        next()

    @httpServer.put '/deploys', (req, res, next) =>
      @server.backend.buildDeploy req.params.deploy, (err, deploySha) ->
        res.send deploySha
        next()

    @httpServer.del '/deploys/:deploy', (req, res, next) =>
      @server.backend.removeDeploy req.params.deploy, (err) ->
        res.send 'Removed'
        next()

    # Register a given backend
    # We'll need to know what kind of backend hosting we're looking at, as well
    # as a service and a service revision to register as
    @httpServer.put '/backends', (req, res, next) =>
      process = new Process()
      process.cwd = req.params.cwd
      process.command = req.params.command
      process.service = req.params.service
      process.revision = req.params.revision
      # TODO: move this lgoic into the ProcessRegistry
      process.config = req.params.config or {}
      for port, service of @server.ports
        # FIXME: loopback isn't long-term accurate
        process.config["#{service.toUpperCase()}_HOST"] or= "http://127.0.0.1:#{port}"
      @server.processes.register process
      res.send "Registered, #{process.id}"
      next()

    # Get all the backends known to the server
    @httpServer.get '/backends', (req, res, next) =>
      processes = (for process in @server.processes.processes
        port: process.port()
        service: process.service
        revision: process.revision
        id: process.id
        running: process.running()
        config: process.config
      )
      res.send processes
      next()

    @httpServer.listen @server.config.control.port

    console.log "Harbor control interface listening on #{@server.config.control.port}"

module.exports = Control
