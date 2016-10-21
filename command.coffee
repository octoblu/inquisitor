_             = require 'lodash'
dashdash      = require 'dashdash'
MeshbluConfig = require 'meshblu-config'
Inquisitor    = require './src/inquisitor'

OPTIONS = [{
  names: ['uuid', 'u']
  type: 'string'
  help: 'The uuid to setup.'
}]

class Command
  constructor: (argv) ->
    process.on 'uncaughtException', @die

  parseOptions: (argv) =>
    parser = dashdash.createParser options: OPTIONS, allowUnknown: true, interspersed: false
    {@uuid} = parser.parse argv

    unless @uuid?
      console.log "Specify which device to set up with -u"
      process.exit 0

  run: =>
    @parseOptions()
    @inquisitor = new Inquisitor {meshbluConfig: new MeshbluConfig().toJSON(), @uuid}
    @inquisitor.setup (error) =>
      return @die error if error?
      console.log "Done."

  die: (error) =>
    return process.exit(0) unless error?
    console.error 'ERROR'
    console.error error.stack
    process.exit 1

  usage: (parser) =>
    return """
    usage: inquisitor -u <uuid>
    setup an inquisitor device
    options:
    #{parser.help({includeEnv: true})}
    """

command = new Command(process.argv)
command.run()
