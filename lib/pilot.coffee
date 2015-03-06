config = require '../etc/config.json'

ChildProcess = require 'child_process'
events = require 'events'
# TODO: real config, pluggable backends
Backend = require './backend'

class Pilot extends events.EventEmitter
  @port = undefined

  @parseArguments: (options) ->
    service: options.s or options.service
    revision: options.r or options.revision
    cwd: '.'

  constructor: (options) ->
    backend = new Backend config

    throw new Error 'No service specified' unless options.service
    throw new Error 'No revision specified' unless options.revision

    # Get a port for us to use.
    backend.getAvailablePort (err, port) =>
      console.log "Starting #{options.command} on #{port}..."

      backendOptions = [ # TODO: hosts are f'ed
        options.service, options.revision, 'localhost', port
      ]

      childEnv = process.env # TODO: clone
      for k, v of options.env or {}
        childEnv[k] = v
      @port = port
      childEnv['PORT'] = port

      @child = ChildProcess.spawn '/bin/sh', ['-c', options.command],
        env: childEnv
        stdio: 'inherit'
        cwd: options.cwd

      # Give us a short time to wait for the service to come alive.
      # TODO: (wait until PORT) is listening for connections
      setTimeout =>
        backend.registerBackend backendOptions..., (err) ->
          console.log err if err
      , 500

      shutdown = =>
        backend.deregisterBackend backendOptions...
        @emit 'exit'
        # process.exit code # TODO: only if process == pilot

      @child.on 'error', (err) =>
        console.log "Error in child: #{err}"
        shutdown()

      @child.on 'exit', (code, signal) ->
        # TODO: respawn in safe conditions
        console.log "Child dead with code: #{code}"
        shutdown()

module.exports = Pilot
