# create-api-test.js
#
# Test the 'create' verb
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
Step = require("step")
_ = require("underscore")
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
setupApp = oauthutil.setupApp
register = oauthutil.register
accessToken = oauthutil.accessToken
newCredentials = oauthutil.newCredentials
newPair = oauthutil.newPair
newClient = oauthutil.newClient
ignore = (err) ->

suite = vows.describe("Create API test")
makeCred = (cl, pair) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret
  token: pair.token
  token_secret: pair.token_secret


# A batch for testing the read access to the API
suite.addBatch "When we set up the app":
  topic: ->
    setupApp @callback

  teardown: (app) ->
    app.close()  if app and app.close

  "it works": (err, app) ->
    assert.ifError err

  "and we get a new client":
    topic: ->
      newClient @callback

    "it works": (err, cl) ->
      assert.ifError err
      assert.isObject cl

    "and we create a new user":
      topic: (cl) ->
        newPair cl, "philippe", "motor*cycle", @callback

      "it works": (err, pair) ->
        assert.ifError err
        assert.isObject pair

      "and the user creates a list":
        topic: (pair, cl) ->
          url = "http://localhost:4815/api/user/philippe/feed"
          cred = makeCred(cl, pair)
          callback = @callback
          Step (->
            act =
              verb: "create"
              object:
                objectType: "collection"
                objectTypes: ["person"]
                displayName: "Jerks"

            httputil.postJSON url, cred, act, this
          ), (err, act, result) ->
            callback err, act


        "it works": (err, act) ->
          assert.ifError err
          assert.isObject act

        "object looks created": (err, act) ->
          assert.ifError err
          assert.isObject act
          assert.include act, "object"
          assert.isObject act.object
          assert.include act.object, "id"
          assert.isString act.object.id
          assert.include act.object, "url"
          assert.isString act.object.url
          assert.include act.object, "links"
          assert.isObject act.object.links
          assert.include act.object.links, "self"
          assert.isObject act.object.links.self
          assert.include act.object.links.self, "href"
          assert.isString act.object.links.self.href

        "and we fetch the object":
          topic: (act, pair, cl) ->
            url = act.object.links.self.href
            cred = makeCred(cl, pair)
            httputil.getJSON url, cred, @callback

          "it works": (err, doc, response) ->
            assert.ifError err
            assert.isObject doc

          "it looks right": (err, doc, response) ->
            assert.isObject doc
            assert.include doc, "id"
            assert.isString doc.id
            assert.include doc, "url"
            assert.isString doc.url
            assert.include doc, "links"
            assert.isObject doc.links
            assert.include doc.links, "self"
            assert.isObject doc.links.self
            assert.include doc.links.self, "href"
            assert.isString doc.links.self.href

suite["export"] module
