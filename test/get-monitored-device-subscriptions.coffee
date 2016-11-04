{afterEach, beforeEach, describe, it} = global
{expect}      = require 'chai'
sinon         = require 'sinon'

_             = require 'lodash'
enableDestroy = require 'server-destroy'
shmock        = require 'shmock'
SocketIO      = require 'socket.io'


Inquisitor    = require '..'

describe 'getMonitoredDeviceSubscriptions', ->
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

  describe '->getMonitoredDeviceSubscriptions', ->
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
            {subscriberUuid: 'inquisitor-uuid', emitterUuid: 'device-1', type: 'configure.sent'}
            {subscriberUuid: 'inquisitor-uuid', emitterUuid: 'device-2', type: 'configure.sent'}
            {subscriberUuid: 'inquisitor-uuid', emitterUuid: 'device-2', type: 'message.received'}
          ]

    describe 'when getting all the subscriptions works swimmingly', ->
      beforeEach 'get-subscriptions', ->
        @meshblu
          .get '/v2/devices/device-1/subscriptions'
          .set 'Authorization', "Basic #{@userAuth}"
          .reply 200, [
            {subscriberUuid: 'device-1', emitterUuid: 'device-1', type: 'configure.sent'}
            {subscriberUuid: 'device-1', emitterUuid: 'device-3', type: 'configure.sent'}
          ]

        @meshblu
          .get '/v2/devices/device-2/subscriptions'
          .set 'Authorization', "Basic #{@userAuth}"
          .reply 200, [
            {subscriberUuid: 'device-2', emitterUuid: 'device-1', type: 'configure.sent'}
            {subscriberUuid: 'device-2', emitterUuid: 'device-2', type: 'configure.sent'}
          ]


      beforeEach (done) ->
        @sut.getMonitoredDeviceSubscriptions (error, @subscriptions) => done()
        return null

      it 'should return an array of objects containing errors associated with devices', ->
        expected = [
          {subscriberUuid: 'device-1', emitterUuid: 'device-1', type: 'configure.sent'}
          {subscriberUuid: 'device-1', emitterUuid: 'device-3', type: 'configure.sent'}
          {subscriberUuid: 'device-2', emitterUuid: 'device-1', type: 'configure.sent'}
          {subscriberUuid: 'device-2', emitterUuid: 'device-2', type: 'configure.sent'}
        ]
        expect(@subscriptions).to.deep.equal expected

    describe 'when getting all the subscriptions, and some have trouble', ->
      beforeEach 'get-subscriptions', ->
        @meshblu
          .get '/v2/devices/device-1/subscriptions'
          .set 'Authorization', "Basic #{@userAuth}"
          .reply 200, [
            {subscriberUuid: 'device-1', emitterUuid: 'device-1', type: 'configure.sent'}
            {subscriberUuid: 'device-1', emitterUuid: 'device-3', type: 'configure.sent'}
          ]

        @meshblu
          .get '/v2/devices/device-2/subscriptions'
          .set 'Authorization', "Basic #{@userAuth}"
          .reply 403


      beforeEach (done) ->
        @sut.getMonitoredDeviceSubscriptions (error, @subscriptions) => done()
        return null

      it 'should return an array of objects containing errors associated with devices', ->
        expected = [
          {subscriberUuid: 'device-1', emitterUuid: 'device-1', type: 'configure.sent'}
          {subscriberUuid: 'device-1', emitterUuid: 'device-3', type: 'configure.sent'}
        ]
        expect(@subscriptions).to.deep.equal expected
