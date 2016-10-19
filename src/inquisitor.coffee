_           = require 'lodash'
async       = require 'async'
MeshbluHttp = require 'meshblu-http'


class Inquisitor
  constructor: ({meshbluConfig, uuid}) ->
    @meshblu = new MeshbluHttp meshbluConfig
    @inquisitorUuid = uuid

  setup: (callback) =>
    @meshblu.device @inquisitorUuid, (error, device) =>
      return callback error if error?

      devices = device.options.devices

      @getStatusDevices devices, (error, statusDevices) =>
         return callback error if error?
         allDevices = _.union devices, statusDevices

         @createSubscriptions allDevices, (error) =>
           return callback error if error?
           callback()

  getStatusDevices: (devices, callback) =>
    @meshblu.search { uuid: $in: devices }, { projection: statusDevice: true }, (error, newDevices) =>
      return callback error if error?
      statusDevices = _.compact _.map newDevices, 'statusDevice'
      callback null, statusDevices

  createSubscriptions: (devices, callback) =>
    subscriptions = _.map devices, (device) => subscriberUuid: @inquisitorUuid, emitterUuid: device, type: 'configure.received'
    async.each subscriptions, @meshblu.createSubscription, callback

module.exports = Inquisitor
