{afterEach, beforeEach, describe, it} = global
{expect}      = require 'chai'
sinon         = require 'sinon'

_             = require 'lodash'
enableDestroy = require 'server-destroy'
shmock        = require 'shmock'
SocketIO      = require 'socket.io'


Inquisitor    = require '..'

describe 'getMonitoredDevices', ->
  beforeEach ->

    meshbluConfig =
      uuid: 'user-uuid'
      token: 'user-token'
      hostname: 'localhost'
      port: 0xd00d
      protocol: 'http'

    uuid = 'inquisitor-uuid'

    @userAuth = new Buffer('user-uuid:user-token').toString 'base64'
    @sut = new Inquisitor {meshbluConfig, uuid}

  it 'should exist', ->
    expect(@sut).to.exist

  describe '->getMonitoredDevices', ->
    beforeEach 'meshblu', ->
      @meshblu = shmock 0xd00d
      enableDestroy(@meshblu)

    afterEach (done) ->
      @meshblu.destroy done

    beforeEach ->
      @meshblu
        .get "/v2/devices/inquisitor-uuid/subscriptions"
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 200, [
            {subscriberUuid: 'inquisitor-uuid', emitterUuid: 'device-1', type: 'configure.received'}
            {subscriberUuid: 'inquisitor-uuid', emitterUuid: 'inquisitor-uuid', type: 'configure.received'}
            {subscriberUuid: 'inquisitor-uuid', emitterUuid: 'device-2', type: 'configure.received'}
            {subscriberUuid: 'inquisitor-uuid', emitterUuid: 'status-device', type: 'configure.received'}
          ]

    beforeEach 'search', ->
      @meshblu
        .post '/search/devices'
        .set 'Authorization', "Basic #{@userAuth}"
        .send uuid: $in: ['device-1', 'device-2', 'status-device']
        .reply 200, [
          {uuid: 'status-device', errors: ['look-an-error']}
          {uuid: 'device-1', statusDevice: 'status-device'}
          {uuid: 'device-2', errors: ['yet-another-error']}
        ]

    beforeEach (done) ->
      @sut.getMonitoredDevices (error, @devicesAndErrors) => done()
      return null

    it 'should return an array of objects containing errors associated with devices', ->
      expected = [
        {
          device: { uuid: 'device-1', statusDevice: 'status-device' }
          statusDevice: 'status-device'
          errors: ['look-an-error']
        }
        {
          device: { uuid: 'device-2', errors: ['yet-another-error'] }
          statusDevice: 'device-2'
          errors: ['yet-another-error']
        }
      ]
      expect(@devicesAndErrors).to.deep.equal expected
