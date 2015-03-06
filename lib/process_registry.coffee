
# This is pretty janky at the moment
class ProcessRegistry
  processes: []

  register: (process, callback) ->
    @processes.push process
    process.start callback
    process.once 'stopped', =>
      @deregister process.id

  deregister: (id, callback) ->
    proc = (p for p in @processes when p.id is id)
    proc[0]?.stop()
    @processes = (p for p in @processes when p.id isnt id)
    callback?()

module.exports = ProcessRegistry
