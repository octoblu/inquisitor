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
            port: @firehoseConfig.port
            protocol: @firehoseConfig.protocol
            uuid: @inquisitorUuid
            token: response.token
          }
        })

        @firehose.on 'message', @_onMessage


        @firehose.connect {uuid: @inquisitorUuid}, callback

  _onMessage: ({metadata, data}) =>
    @emit 'message', {metadata, data}
    return unless _.last(metadata.route).type == 'configure.received'

    statusDevice  =  _.last(_.initial(metadata.route)).from
    {device}      = _.find(@monitoredDevices, {statusDevice}) || {}

    return unless device?

    device        = data if device.uuid == statusDevice

    emitMessage =
      uuid: device.uuid
      statusDevice: statusDevice
      errors: data.errors
      device: device

    @emit 'status-update', emitMessage


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
    deviceMap = {}
    _.each devices, (device) =>
      return if _.some devices, statusDevice: device.uuid
      unless device.statusDevice?
        deviceMap[device.uuid] = {device, statusDevice: device.uuid, errors: device.errors}
        return

      statusDevice = _.find devices, uuid: device.statusDevice
      deviceMap[device.uuid] = {device, statusDevice: device.statusDevice, errors: statusDevice?.errors || []}

    return deviceMap


  createSubscriptions: (devices, callback) =>
    async.each devices, @_createSubscription, callback

  _createSubscription: (device, callback) =>
    subscriptions = [
      {subscriberUuid: @inquisitorUuid, emitterUuid: device, type: 'configure.received'}
      {subscriberUuid: @inquisitorUuid, emitterUuid: device, type: 'message.received'}
      {subscriberUuid: @inquisitorUuid, emitterUuid: device, type: 'message.sent'}
      {subscriberUuid: @inquisitorUuid, emitterUuid: device, type: 'broadcast.sent'}
    ]
    async.eachSeries subscriptions, @meshblu.createSubscription, callback

  updatePermissions: (devices, callback) =>
    query = {uuid: {$in: devices}, 'meshblu.version': '2.0.0'}
    @meshblu.search {query: query, projection: {uuid: true}}, (error, v2Devices) =>
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

  getMonitoredDeviceSubscriptions: (callback) =>
    @meshblu.listSubscriptions {subscriberUuid: @inquisitorUuid}, (error, subscriptions) =>
      return callback error if error?
      subscriptionQueries =
        _(subscriptions)
          .uniqBy('emitterUuid')
          .reject emitterUuid: @inquisitorUuid
          .map ({emitterUuid}) => {subscriberUuid: emitterUuid}
          .compact()
          .value()

      async.map subscriptionQueries, @meshblu.listSubscriptions, (error, subscriptions) =>
        return callback null, [] if error?
        return callback null, _.flatten(subscriptions)

module.exports = Inquisitor
