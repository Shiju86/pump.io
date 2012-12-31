# scrubber-favorite-api-test.js
#
# Test posting filthy HTML to the favorites endpoint
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
querystring = require("querystring")
http = require("http")
OAuth = require("oauth").OAuth
Browser = require("zombie")
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
actutil = require("./lib/activity")
setupApp = oauthutil.setupApp
newCredentials = oauthutil.newCredentials
newPair = oauthutil.newPair
newClient = oauthutil.newClient
register = oauthutil.register
accessToken = oauthutil.accessToken
DANGEROUS = "This is a <script>alert('Boo!')</script> dangerous string."
HARMLESS = "This is a harmless string."
deepProperty = (object, property) ->
  i = property.indexOf(".")
  unless object
    null
  else if i is -1 # no dots
    object[property]
  else
    deepProperty object[property.substr(0, i)], property.substr(i + 1)

postFavorite = (obj) ->
  url = "http://localhost:4815/api/user/shatner/favorites"
  topic: (cred) ->
    httputil.postJSON url, cred, obj, @callback

  "it works": (err, result, response) ->
    assert.ifError err
    assert.isObject result

goodFavorite = (obj, property) ->
  compare = deepProperty(obj, property)
  context = postFavorite(obj)
  context["it is unchanged"] = (err, result, response) ->
    assert.ifError err
    assert.isObject result
    assert.equal deepProperty(result, property), compare

  context

badFavorite = (obj, property) ->
  context = postFavorite(obj)
  context["it is defanged"] = (err, result, response) ->
    assert.ifError err
    assert.isObject result
    assert.equal deepProperty(result, property).indexOf("<script>"), -1

  context

privateFavorite = (obj, property) ->
  context = postFavorite(obj)
  context["private property is ignored"] = (err, result, response) ->
    assert.ifError err
    assert.isObject result
    assert.isFalse _.has(result, property)

  context

suite = vows.describe("Scrubber favorite API test")

# A batch to test posting to the regular feed endpoint
suite.addBatch "When we set up the app":
  topic: ->
    setupApp @callback

  teardown: (app) ->
    app.close()  if app and app.close

  "it works": (err, app) ->
    assert.ifError err

  "and we get a new set of credentials":
    topic: ->
      oauthutil.newCredentials "shatner", "deep*fried*turkey", @callback

    "it works": (err, cred) ->
      assert.ifError err
      assert.isObject cred

    "and we favorite an object with good content": goodFavorite(
      objectType: "note"
      id: "urn:uuid:9aa257b4-3291-11e2-a4d3-0024beb67924"
      content: HARMLESS
    , "content")
    "and we favorite an object with bad content": badFavorite(
      objectType: "note"
      id: "urn:uuid:9aa2f1b0-3291-11e2-b8c5-0024beb67924"
      content: DANGEROUS
    , "content")
    "and we favorite an object with good summary": goodFavorite(
      objectType: "note"
      id: "urn:uuid:9aa38bf2-3291-11e2-96dc-0024beb67924"
      summary: HARMLESS
    , "summary")
    "and we favorite an object with bad summary": badFavorite(
      objectType: "note"
      id: "urn:uuid:9aa42710-3291-11e2-b22d-0024beb67924"
      summary: DANGEROUS
    , "summary")
    "and we favorite an object with a private member": privateFavorite(
      objectType: "person"
      id: "urn:uuid:20605d22-36ae-11e2-9e3d-70f1a154e1aa"
      _user: true
      summary: HARMLESS
    , "_user")

suite["export"] module
