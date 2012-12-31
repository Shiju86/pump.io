# Dialback client test
#
# Copyright 2012 StatusNet Inc.
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
vows = require("vows")
assert = require("assert")
express = require("express")
querystring = require("querystring")
databank = require("databank")
fs = require("fs")
path = require("path")
Databank = databank.Databank
DatabankObject = databank.DatabankObject
suite = vows.describe("DialbackClient post interface")
tc = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json")))
suite.addBatch "When we set up a dummy echo app":
  topic: ->
    callback = @callback
    app = express.createServer()
    connected = false
    app.post "/echo", (req, res, next) ->
      parseFields = (str) ->
        fstr = str.substr(9) # everything after "Dialback "
        pairs = fstr.split(/,\s+/) # XXX: won't handle blanks inside values well
        fields = {}
        pairs.forEach (pair) ->
          kv = pair.split("=")
          key = kv[0]
          value = kv[1].replace(/^"|"$/g, "")
          fields[key] = value

        fields

      auth = req.headers.authorization
      fields = parseFields(auth)
      res.json fields

    app.on "error", (err) ->
      callback err, null  unless connected

    app.listen 80, "echo.localhost", ->
      connected = true
      callback null, app


  "it works": (err, app) ->
    assert.ifError err

  teardown: (app) ->
    app.close()  if app and app.close

  "And we require the DialbackClient module":
    topic: ->
      cb = @callback
      db = Databank.get(tc.driver, tc.params)
      db.connect {}, (err) ->
        if err
          cb err, null
        else
          DatabankObject.bank = db
          cb null, require("../lib/dialbackclient")


    "it works": (err, DialbackClient) ->
      assert.ifError err
      assert.isObject DialbackClient

    "and we post to the echo endpoint":
      topic: (DialbackClient) ->
        body = querystring.stringify(type: "client_associate")
        type = "application/x-www-form-urlencoded"
        url = "http://echo.localhost/echo"
        id = "acct:user@photo.example"
        callback = @callback
        DialbackClient.post url, id, body, type, callback

      "it works": (err, res, body) ->
        assert.ifError err

      "echo data includes token and id": (err, res, body) ->
        parts = undefined
        assert.ifError err
        assert.isTrue res.headers["content-type"].substr(0, "application/json".length) is "application/json"
        try
          parts = JSON.parse(body)
        catch err
          assert.ifError err
        assert.isObject parts
        assert.include parts, "webfinger"
        assert.equal parts.webfinger, "acct:user@photo.example"
        assert.include parts, "token"
        assert.isString parts.token

suite["export"] module
