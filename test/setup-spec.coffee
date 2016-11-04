{afterEach, beforeEach, describe, it} = global
{expect}      = require 'chai'
sinon         = require 'sinon'

_             = require 'lodash'
enableDestroy = require 'server-destroy'
shmock        = require 'shmock'
SocketIO      = require 'socket.io'


Inquisitor    = require '..'

describe 'Setup', ->
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
          devices: ['device-1', 'device-2']

      @meshblu
        .post '/search/devices'
        .send uuid: $in: ['device-1', 'device-2']
        .set 'Authorization', "Basic #{@userAuth}"
        .set 'x-meshblu-projection', JSON.stringify({statusDevice: true})
        .reply 200, [{}, {statusDevice: 'status-device'}]


    beforeEach 'subscriptions', ->
      @subscriptionRequests = []
      @subscriptionRequests.push( @meshblu
        .post '/v2/devices/inquisitor-uuid/subscriptions/device-1/configure.sent'
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 201
      )

      @subscriptionRequests.push( @meshblu
        .post '/v2/devices/inquisitor-uuid/subscriptions/device-1/message.received'
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 201
      )

      @subscriptionRequests.push( @meshblu
        .post '/v2/devices/inquisitor-uuid/subscriptions/device-1/message.sent'
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 201
      )

      @subscriptionRequests.push( @meshblu
        .post '/v2/devices/inquisitor-uuid/subscriptions/device-1/broadcast.sent'
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 201
      )

      @subscriptionRequests.push( @meshblu
        .post '/v2/devices/inquisitor-uuid/subscriptions/device-2/configure.sent'
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 201
      )

      @subscriptionRequests.push( @meshblu
        .post '/v2/devices/inquisitor-uuid/subscriptions/device-2/message.received'
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 201
      )

      @subscriptionRequests.push( @meshblu
        .post '/v2/devices/inquisitor-uuid/subscriptions/device-2/message.sent'
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 201
      )

      @subscriptionRequests.push( @meshblu
        .post '/v2/devices/inquisitor-uuid/subscriptions/device-2/broadcast.sent'
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 201
      )

      @subscriptionRequests.push( @meshblu
        .post '/v2/devices/inquisitor-uuid/subscriptions/status-device/configure.sent'
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 201
      )

      @subscriptionRequests.push( @meshblu
        .post '/v2/devices/inquisitor-uuid/subscriptions/status-device/message.received'
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 201
      )

      @subscriptionRequests.push( @meshblu
        .post '/v2/devices/inquisitor-uuid/subscriptions/status-device/message.sent'
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 201
      )

      @subscriptionRequests.push( @meshblu
        .post '/v2/devices/inquisitor-uuid/subscriptions/status-device/broadcast.sent'
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 201
      )

      @subscriptionRequests.push( @meshblu
        .post '/v2/devices/inquisitor-uuid/subscriptions/inquisitor-uuid/configure.sent'
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 201
      )

      @subscriptionRequests.push( @meshblu
        .post '/v2/devices/inquisitor-uuid/subscriptions/inquisitor-uuid/message.received'
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 201
      )

      @subscriptionRequests.push( @meshblu
        .post '/v2/devices/inquisitor-uuid/subscriptions/inquisitor-uuid/message.sent'
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 201
      )

      @subscriptionRequests.push( @meshblu
        .post '/v2/devices/inquisitor-uuid/subscriptions/inquisitor-uuid/broadcast.sent'
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 201
      )

    beforeEach 'permissions', ->
      @meshblu
        .post '/search/devices'
        .set 'Authorization', "Basic #{@userAuth}"
        .set 'x-meshblu-projection', JSON.stringify({uuid: true})
        .send 'meshblu.version': '2.0.0', uuid: $in: ['device-1', 'device-2', 'status-device']
        .reply 200, [{uuid: 'status-device'}, {uuid: 'device-1'}]

      @updateDevice1 = @meshblu
        .put '/v2/devices/device-1'
        .set 'Authorization', "Basic #{@userAuth}"
        .send $addToSet: { 'meshblu.whitelists.configure.sent': {uuid: 'inquisitor-uuid'}, 'meshblu.whitelists.discover.view': {uuid: 'inquisitor-uuid'} }
        .reply 204

      @updateDevice2 = @meshblu
        .put '/v2/devices/device-2'
        .set 'Authorization', "Basic #{@userAuth}"
        .send $addToSet: { 'configureWhitelist': 'inquisitor-uuid', 'discoverWhitelist': 'inquisitor-uuid'}
        .reply 204

      @updateStatusDevice = @meshblu
        .put '/v2/devices/status-device'
        .set 'Authorization', "Basic #{@userAuth}"
        .send $addToSet: { 'meshblu.whitelists.configure.sent': {uuid: 'inquisitor-uuid'}, 'meshblu.whitelists.discover.view': {uuid: 'inquisitor-uuid'} }
        .reply 403

    beforeEach 'old-subscriptions', ->
      @meshblu.get '/v2/devices/inquisitor-uuid/subscriptions'
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 200, [
          subscriberUuid: 'inquisitor-uuid'
          emitterUuid: 'whoever-uuid'
          type: 'message.received'
        ]

      @deleteOldSubscription =
        @meshblu.delete '/v2/devices/inquisitor-uuid/subscriptions/whoever-uuid/message.received'
          .set 'Authorization', "Basic #{@userAuth}"
          .reply 204


    beforeEach (done) ->
      @sut.setup done
      return null

    it 'should delete the old subscriptions', ->
      @deleteOldSubscription.done()

    it 'should create all them subscriptions', ->
      _.each @subscriptionRequests, (request) => request.done()

    it 'should update the whitelist for device-1', ->
      @updateDevice1.done()

    it 'should update the whitelist for device-2', ->
      @updateDevice2.done()

    it 'should update the whitelist for the status-device', ->
      @updateStatusDevice.done()
