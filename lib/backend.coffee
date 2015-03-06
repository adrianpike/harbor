async = require 'async'
crypto = require 'crypto'
redis = require 'redis'

# TODO: Appropriate caching
# TODO: pluggable backends

# yeah this says it's a Backend but it's really a RedisBackend.
class Backend

  constructor: (@config) ->
    @client = redis.createClient @config.storage.port or 6379, @config.storage.host or '127.0.0.1'

  # Returns a hash of ports --> service names
  servicePorts: (callback) ->
    @client.hgetall 'harbor:ports', callback

  getAvailablePort: (callback) ->
    # OH GOD THIS IS FUCKED
    callback null, Math.floor Math.random() * 20000 + 1000

  registerPort: (port, service, callback) ->
    @client.hset 'harbor:ports', port, service, callback

  unregisterPort: (port, callback) ->
    @client.hdel 'harbor:ports', port, callback

  # Returns a hash of domains --> Deploy SHA's
  domainRevisions: (callback) ->
    @client.hgetall 'harbor:domains', callback

  routeDomain: (domain, deploySha, callback) ->
    @client.hset 'harbor:domains', domain, deploySha, callback

  unrouteDomain: (domain, callback) ->
    @client.hdel 'harbor:domains', domain, callback

  # Returns all known backends for a given service
  backendsForService: (service, callback) ->
    @client.keys "harbor:backends:#{service}:*", (err, keys) ->
      # TODO: incomplete
      callback null, keys

  # Returns all "host:port" strings given a service & Deploy SHA
  backendsForServiceAndDeploy: (service, deploySha, callback) =>
    @servicesForDeploy deploySha, (err, services = {}) =>
      serviceSha = services[service]
      @client.lrange "harbor:backends:#{service}:#{serviceSha}", 0, -1, callback

  registerBackend: (service, serviceSha, host, port, callback) ->
    @client.lpush "harbor:backends:#{service}:#{serviceSha}", "#{host}:#{port}", callback

  deregisterBackend: (service, serviceSha, host, port, callback) ->
    @client.lrem "harbor:backends:#{service}:#{serviceSha}", 0, "#{host}:#{port}", callback

  deploys: (callback) ->
    @client.keys "harbor:deploys:*", (err, keys) ->
      callback null, (key.split(':')?[2] for key in keys)

  # Returns the services given a Deploy SHA
  servicesForDeploy: (deploySha, callback) ->
    @client.hgetall "harbor:deploys:#{deploySha}", callback

  buildDeploy: (services, callback) ->
    deploySha = crypto.randomBytes(20).toString 'hex'
    async.each Object.keys(services), (service, callback) =>
      @deployService deploySha, service, services[service], callback
    , (err) ->
      callback err, deploySha

  deployService: (deploySha, service, sha, callback) ->
    @client.hset "harbor:deploys:#{deploySha}", service, sha, callback

  removeDeploy: (deploySha, callback) ->
    @client.del "harbor:deploys:#{deploySha}", callback

  # Removes a backend "host:port" string from a service and service SHA
  removeBackend: (service, serviceSha, host, callback) ->
    @client.lrem "harbor:backends:#{service}:#{serviceSha}", 1, host, callback

module.exports = Backend
