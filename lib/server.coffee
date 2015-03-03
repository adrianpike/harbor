config = require '../etc/config.json'

Backend = require './backend' # TODO: pluggable
# TODO: Config = require './config'
Control = require './control'
Proxy = require './proxy'
ProcessRegistry = require './process_registry' # TODO: pluggable (replacable with Heroku?)

class Server
  backend: undefined
  config: {}
  ports: {}
  proxies: {}

  constructor: ->
    @config = config

    # TODO: pluggable backends
    @backend = new Backend @config
    @processes = new ProcessRegistry @config

    if @config.control.port
      @control = new Control @
    setInterval =>
      @updateState()
    , (@config.control.updateInterval or 5000)
    @updateState()

    console.log "Harbor up and running, happy as a clam."

  updateState: (callback = ->) ->
    @backend.servicePorts (err, ports) =>
      @ports = ports
      @listenProxy()
      callback()

  listenProxy: ->
    # Kill any proxies that aren't in our port list anymore
    for port, proxy of @proxies
      unless @ports[port]
        proxy.shutdown()

    # Proxy 'em up!
    for port, service of @ports
      unless @proxies[port]
        @proxies[port] = new Proxy(port, service, @backend)

module.exports = Server
