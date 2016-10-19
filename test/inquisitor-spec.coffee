{afterEach, beforeEach, describe, it} = global
{expect}      = require 'chai'
sinon         = require 'sinon'

_             = require 'lodash'
enableDestroy = require 'server-destroy'
shmock        = require 'shmock'
SocketIO      = require 'socket.io'


Inquisitor    = require '..'

describe 'Inquisitor', ->
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

  describe '->setup', ->
    beforeEach 'meshblu', ->
      @meshblu = shmock 0xd00d
      enableDestroy(@meshblu)

    afterEach (done) ->
      @meshblu.destroy done

    beforeEach ->
      @meshblu
        .get "/v2/devices/inquisitor-uuid"
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 200,
          uuid: 'inquisitor-uuid'
          options:
            devices: ['device-1', 'device-2']

      @meshblu
        .post '/search/devices'
        .send uuid: $in: ['device-1', 'device-2']
        .set 'Authorization', "Basic #{@userAuth}"
        .set 'x-meshblu-projection', JSON.stringify({statusDevice: true})
        .reply 200, [{}, {statusDevice: 'status-device'}]


    beforeEach 'subscriptions', (done) ->
      @device1Subscription = @meshblu
        .post '/v2/devices/inquisitor-uuid/subscriptions/device-1/configure.received'
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 201

      @device2Subscription = @meshblu
        .post '/v2/devices/inquisitor-uuid/subscriptions/device-2/configure.received'
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 201

      @statusDeviceSubscription = @meshblu
        .post '/v2/devices/inquisitor-uuid/subscriptions/status-device/configure.received'
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 201

      @sut.setup done

    it 'should create the configure.received subscription for device-1', ->
      @device1Subscription.done()

    it 'should create the configure.received subscription for device-2', ->
      @device2Subscription.done()

    it 'should create the configure.received subscription for the status-device', ->
      @statusDeviceSubscription.done()
