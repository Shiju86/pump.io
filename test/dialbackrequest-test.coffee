# credentials-test.js
#
# Test the credentials module
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
databank = require("databank")
Step = require("step")
URLMaker = require("../lib/urlmaker").URLMaker
modelBatch = require("./lib/model").modelBatch
Databank = databank.Databank
DatabankObject = databank.DatabankObject
suite = vows.describe("dialbackrequest module interface")
testSchema =
  pkey: "endpoint_id_token_timestamp"
  fields: ["endpoint", "id", "token", "timestamp"]

testData = create:
  endpoint: "social.example/register"
  id: "acct:user@comment.example"
  token: "AAAAAA"
  timestamp: Date.now()

mb = modelBatch("dialbackrequest", "DialbackRequest", testSchema, testData)
delete mb["When we require the dialbackrequest module"]["and we get its DialbackRequest class export"]["and we create a dialbackrequest instance"]["auto-generated fields are there"]

delete mb["When we require the dialbackrequest module"]["and we get its DialbackRequest class export"]["and we create a dialbackrequest instance"]["and we modify it"]

suite.addBatch mb
suite.addBatch "When we get the class":
  topic: ->
    require("../lib/model/dialbackrequest").DialbackRequest

  "it works": (DialbackRequest) ->
    assert.isFunction DialbackRequest

  "it has a cleanup() method": (DialbackRequest) ->
    assert.isFunction DialbackRequest.cleanup

  "and we create a lot of requests":
    topic: (DialbackRequest) ->
      cb = @callback
      Step (->
        i = undefined
        group = @group()
        ts = Date.now() - (24 * 60 * 60 * 1000)
        i = 0
        while i < 100
          DialbackRequest.create
            endpoint: "social.example/register"
            id: "acct:user@comment.example"
            token: "OLDTOKEN" + i
            timestamp: ts
          , group()
          i++
      ), ((err, reqs) ->
        throw err  if err
        i = undefined
        group = @group()
        ts = Date.now()
        i = 0
        while i < 100
          DialbackRequest.create
            endpoint: "social.example/register"
            id: "acct:user@comment.example"
            token: "RECENT" + i
            timestamp: ts
          , group()
          i++
      ), (err, reqs) ->
        if err
          cb err
        else
          cb null


    "it works": (err) ->
      assert.ifError err

    "and we try to cleanup":
      topic: (DialbackRequest) ->
        DialbackRequest.cleanup @callback

      "it works": (err) ->
        assert.ifError err

suite["export"] module
