{afterEach, beforeEach, describe, it} = global
{expect}      = require 'chai'
sinon         = require 'sinon'
URL           = require 'url'
_             = require 'lodash'
enableDestroy = require 'server-destroy'
shmock        = require 'shmock'
SocketIO      = require 'socket.io'
Inquisitor    = require '..'

describe 'connect', ->
  beforeEach 'meshblu', ->
    @meshblu = shmock 0xd00d
    enableDestroy(@meshblu)

  afterEach (done) ->
    @meshblu.destroy done

  beforeEach 'setup socket.io', ->
    @firehoseServer = new SocketIO 0xcaf1

  afterEach 'close socket.io', (done) ->
    _.delay =>
      @firehoseServer.close()
      done()
    , 50

  beforeEach ->
    meshbluConfig =
      uuid: 'user-uuid'
      token: 'user-token'
      hostname: 'localhost'
      port: 0xd00d
      protocol: 'http'

    firehoseConfig =
      hostname: 'localhost'
      port: 0xcaf1
      protocol: 'http'

    uuid = 'inquisitor-uuid'

    @userAuth = new Buffer('user-uuid:user-token').toString 'base64'
    @sut = new Inquisitor {meshbluConfig, firehoseConfig, uuid}

  it 'should exist', ->
    expect(@sut).to.exist

  describe '->connect', ->
    beforeEach ->
      @meshblu
        .post '/devices/inquisitor-uuid/tokens'
        .set 'Authorization', "Basic #{@userAuth}"
        .reply 201, uuid: "inquisitor-uuid", token: "inquisitor-token"

    beforeEach 'mock getMonitoredDevices, out of laziness', ->
      @deviceMap = [
        {
          device: { uuid: 'device-1', statusDevice: 'status-device', otherProperty: false }
          statusDevice: 'status-device'
          errors: ['look-an-error']
        }
        {
          device: { uuid: 'device-2', errors: ['yet-another-error'] }
          statusDevice: 'device-2'
          errors: ['yet-another-error']
        }
      ]
      @sut.getMonitoredDevices = sinon.stub().yields null, @deviceMap

    beforeEach (done) ->
      @firehoseServer.on 'connection', (@socket) =>

        {@pathname, @query} = URL.parse @socket.client.request.url, true
        @uuid = @socket.client.request.headers['x-meshblu-uuid']
        @token = @socket.client.request.headers['x-meshblu-token']
        done()

      @sut.connect =>
      return null

    afterEach (done) ->
      @sut.stop done
      return null

    it 'should connect', ->
      expect(@socket).to.exist
      expect(@pathname).to.equal '/socket.io/v1/inquisitor-uuid/'

    it 'should pass along the auth info', ->
      expect(@uuid).to.equal 'inquisitor-uuid'
      expect(@token).to.equal 'inquisitor-token'
      expect(@query.uuid).to.equal 'inquisitor-uuid'
      expect(@query.token).to.equal 'inquisitor-token'

    describe 'when we get a config update from the firehose', ->
      beforeEach (done) ->
        @sut.on 'message', (@message) => done()
        changeEvent =
          metadata:
            route: [
              {
                from: "device-2"
                to: "inquisitor-uuid"
                type: "configure.received"
              }
              {
                from: "inquisitor-uuid"
                to: "inquisitor-uuid"
                type: "configure.received"
              }
            ]
          rawData: JSON.stringify(
            uuid: "device-2"
            errors: [
              message: '#watchit'
              code: 101
            ]
          )
        @socket.emit 'message', changeEvent

      it 'should emit a message in the right format', ->
        expectedMessage =
          uuid: 'device-2'
          statusDevice: 'device-2'
          errors: [
            message: '#watchit'
            code: 101
          ]
          device:
            uuid: "device-2"
            errors: [
              message: '#watchit'
              code: 101
            ]
        expect(@message).to.deep.equal expectedMessage


    describe 'when we get a config update from the firehose from a status-device', ->
      beforeEach (done) ->
        @sut.on 'message', (@message) => done()

        changeEvent =
          metadata:
            route: [
              {
                from: "status-device"
                to: "inquisitor-uuid"
                type: "configure.received"
              }
              {
                from: "inquisitor-uuid"
                to: "inquisitor-uuid"
                type: "configure.received"
              }
            ]
          rawData: JSON.stringify(
            uuid: "status-device"
            errors: [
              message: '#watchit'
              code: 101
            ]
          )
        @socket.emit 'message', changeEvent

      it 'should emit a message in the right format', ->
        expectedMessage =
          statusDevice: 'status-device'
          uuid: 'device-1'
          errors: [
            message: '#watchit'
            code: 101
          ]
          device:
            uuid: 'device-1'
            statusDevice: 'status-device'
            otherProperty: false

        expect(@message).to.deep.equal expectedMessage
