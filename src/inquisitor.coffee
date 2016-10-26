_           = require 'lodash'
async       = require 'async'
MeshbluHttp = require 'browser-meshblu-http'
MeshbluHose = require 'meshblu-firehose-socket.io/src/firehose-socket-io.coffee'
EventEmitter = require 'eventemitter2'

class Inquisitor extends EventEmitter
  constructor: ({meshbluConfig, @firehoseConfig, uuid}) ->
    @meshblu = new MeshbluHttp meshbluConfig
    @inquisitorUuid = uuid

  setup: (callback) =>
    @meshblu.device @inquisitorUuid, (error, device) =>
      return callback error if error?

      devices = device.devices

      @_createSubscription @inquisitorUuid, (error) =>
        return callback error if error?

        @getStatusDevices devices, (error, statusDevices) =>
           return callback error if error?
           allDevices = _.union devices, statusDevices

           @createSubscriptions allDevices, (error) =>
             return callback error if error?
             @updatePermissions allDevices, callback

  connect: (callback) =>
    @getMonitoredDevices (error, @monitoredDevices) =>
      return callback error if error?
      @meshblu.generateAndStoreToken @inquisitorUuid, {}, (error, response) =>
        return callback error if error?
        @firehose = new MeshbluHose({
          meshbluConfig: {
           hostname: @firehoseConfig.hostname
           port: @firehoseConfig.port,
           protocol: @firehoseConfig.protocol
           uuid: @inquisitorUuid,
           token: response.token
          }
        })

        @firehose.on 'message', @_onMessage


        @firehose.connect {uuid: @inquisitorUuid}, callback

  _onMessage: ({metadata, data}) =>
    statusDevice =  _.last(_.initial(metadata.route)).from
    {device} = _.find @monitoredDevices, {statusDevice}
    device = data if device.uuid == statusDevice

    emitMessage =
      statusDevice: statusDevice
      errors: data.errors
      device: device

    @emit 'message', emitMessage


  stop: (callback) =>
    return callback() unless @firehose?
    @firehose.close callback

  getStatusDevices: (devices, callback) =>
    @meshblu.search {query: {uuid: $in: devices }, projection: {statusDevice: true }}, (error, newDevices) =>
      return callback error if error?
      statusDevices = _.compact _.map newDevices, 'statusDevice'
      callback null, statusDevices

  getMonitoredDevices: (callback) =>
    @meshblu.listSubscriptions {subscriberUuid: @inquisitorUuid}, (error, subscriptions) =>
      return callback error if error?
      subscribedDevices = _.without _.map(subscriptions, 'emitterUuid'), @inquisitorUuid
      @meshblu.search {query: {uuid: $in: subscribedDevices}}, (error, devices) =>
        return callback error if error?
        callback null, @mapStatusDevices devices

  mapStatusDevices: (devices) =>
    _.compact _.map devices, (device) =>
      return if _.some devices, statusDevice: device.uuid
      return {device, statusDevice: device.uuid, errors: device.errors} unless device.statusDevice?
      statusDevice = _.find devices, uuid: device.statusDevice
      return {device, statusDevice: statusDevice.uuid, errors: statusDevice.errors}


  createSubscriptions: (devices, callback) =>
    async.each devices, @_createSubscription, callback

  _createSubscription: (device, callback) =>
    subscription = subscriberUuid: @inquisitorUuid, emitterUuid: device, type: 'configure.received'
    @meshblu.createSubscription subscription, callback

  updatePermissions: (devices, callback) =>
    @meshblu.search {query: {uuid: {$in: devices}, 'meshblu.version': '2.0.0'}, projection: {uuid: true}}, (error, v2Devices) =>
      return callback error if error?
      v2Devices = _.map v2Devices, 'uuid'
      v1Devices = _.difference devices, v2Devices
      @updateV1Devices v1Devices, (error) =>
        return callback error if error?
        @updateV2Devices v2Devices, callback

  updateV1Devices: (devices, callback) =>
    async.each devices, @_updateV1Device, callback

  _updateV1Device: (device, callback) =>
    update =
      $addToSet:
        configureWhitelist: @inquisitorUuid
        discoverWhitelist: @inquisitorUuid
    @meshblu.updateDangerously device, update, callback

  updateV2Devices: (devices, callback) =>
    async.each devices, @_updateV2Device, callback

  _updateV2Device: (device, callback) =>
    update =
      $addToSet:
        'meshblu.whitelists.configure.received': uuid: @inquisitorUuid
        'meshblu.whitelists.discover.view': uuid: @inquisitorUuid

    @meshblu.updateDangerously device, update, callback

  clearErrors: (uuid, callback) =>
    update =
      $unset:
        errors: true
    @meshblu.updateDangerously uuid, update, callback

module.exports = Inquisitor
