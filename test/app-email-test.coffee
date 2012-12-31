# app-email-test.js
#
# Test sending email through the app
#
# Copyright 2012, StatusNet Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
assert = require("assert")
vows = require("vows")
simplesmtp = require("simplesmtp")
_ = require("underscore")
Step = require("step")
fs = require("fs")
path = require("path")
suite = vows.describe("app email interface")
oneEmail = (smtp, addr, callback) ->
  data = undefined
  isOurs = (envelope) ->
    _.has(envelope, "to") and _.isArray(envelope.to) and _.contains(envelope.to, addr)

  starter = (envelope) ->
    if isOurs(envelope)
      data = ""
      smtp.on "data", accumulator
      smtp.once "dataReady", ender

  accumulator = (envelope, chunk) ->
    data = data + chunk.toString()  if isOurs(envelope)

  ender = (envelope, cb) ->
    if isOurs(envelope)
      smtp.removeListener "data", accumulator
      callback null, _.extend(
        data: data
      , envelope)
    cb null, "ABC123"

  smtp.on "startData", starter

tc = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json")))
suite.addBatch "When we makeApp()":
  topic: ->
    config =
      port: 4815
      hostname: "localhost"
      driver: tc.driver
      params: tc.params
      smtpserver: "localhost"
      smtpport: 1623
      sockjs: false
      nologger: true

    smtp = simplesmtp.createServer(disableDNSValidation: true)
    app = undefined
    callback = @callback
    Step (->
      smtp.listen 1623, this
    ), ((err) ->
      throw err  if err
      makeApp = require("../lib/app").makeApp
      process.env.NODE_ENV = "test"
      makeApp config, this
    ), ((err, result) ->
      throw err  if err
      app = result
      app.run this
    ), (err) ->
      if err
        callback err, null, null
      else
        callback null, app, smtp


  teardown: (app, smtp) ->
    app.close()  if app and app.close
    if smtp
      smtp.end (err) ->


  "it works": (err, app, smtp) ->
    assert.ifError err
    assert.isObject app
    assert.isObject smtp

  "app has the sendEmail() method": (err, app) ->
    assert.isFunction app.run

  "and we send an email":
    topic: (app, smtp) ->
      addr = "fakeuser@email.localhost"
      msg =
        to: addr
        subject: "Test email"
        text: "Hello, world!"

      callback = @callback
      Step (->
        cb1 = @parallel()
        cb2 = @parallel()
        oneEmail smtp, addr, (err, data) ->
          cb1 err, data

        app.sendEmail msg, (err, message) ->
          cb2 err, message

      ), (err, data, message) ->
        if err
          callback err, null, null
        else
          callback null, data, message


    "it works": (err, data, message) ->
      assert.ifError err
      assert.isObject data
      assert.isObject message

    "client results are correct": (err, data, message) ->
      assert.ifError err
      assert.isObject data
      assert.isObject message
      assert.equal message.header.from, "no-reply@localhost"
      assert.equal message.header.to, "fakeuser@email.localhost"
      assert.equal message.header.subject, "Test email"
      assert.equal message.text, "Hello, world!"

    "server results are correct": (err, data, message) ->
      assert.ifError err
      assert.isObject data
      assert.isObject message
      assert.equal data.from, "no-reply@localhost"
      assert.lengthOf data.to, 1
      assert.include data.to, "fakeuser@email.localhost"

suite["export"] module
