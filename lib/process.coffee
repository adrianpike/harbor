Pilot = require './pilot'
events = require 'events'

class Process extends events.EventEmitter # TODO: other types obviously
  kind: 'pilot'
  cwd: '.'
  command: null
  service: null
  revision: null
  id: null
  started: false
  config: {}

  @generateId: ->
    Math.random().toString(36).slice 2

  start: (callback) ->
    @id = Process.generateId() unless @id
    options =
      service: @service
      revision: @revision
      command: @command
      cwd: @cwd
      env: @config

    @pilot = new Pilot options
    @pilot.once 'exit', =>
      @stop()

    @started = true

    callback?()

  stop: (callback) ->
    if @started
      console.log "Process #{@id} stopping..."
      # TODO: kill the pilot if we're a pilot
      @emit 'stopped'
      @started = false
    callback?()

  port: ->
    if @kind is 'pilot'
      @pilot?.port

  running: ->
    if @kind is 'pilot'
      @pilot?.port?

module.exports = Process
