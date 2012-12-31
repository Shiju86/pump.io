# scrubber-follow-api-test.js
#
# Test posting filthy HTML to the follows endpoint
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

postFollow = (obj) ->
  url = "http://localhost:4815/api/user/shatner/following"
  topic: (cred) ->
    httputil.postJSON url, cred, obj, @callback

  "it works": (err, result, response) ->
    assert.ifError err
    assert.isObject result

goodFollow = (obj, property) ->
  compare = deepProperty(obj, property)
  context = postFollow(obj)
  context["it is unchanged"] = (err, result, response) ->
    assert.ifError err
    assert.isObject result
    assert.equal deepProperty(result, property), compare

  context

badFollow = (obj, property) ->
  context = postFollow(obj)
  context["it is defanged"] = (err, result, response) ->
    assert.ifError err
    assert.isObject result
    assert.equal deepProperty(result, property).indexOf("<script>"), -1

  context

privateFollow = (obj, property) ->
  context = postFollow(obj)
  context["The private property is ignored"] = (err, result, response) ->
    assert.ifError err
    assert.isObject result
    assert.isFalse _.has(result, property)

  context

suite = vows.describe("Scrubber follow API test")

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

    "and we follow an object with good content": goodFollow(
      objectType: "person"
      id: "urn:uuid:31981bb2-3293-11e2-98b1-0024beb67924"
      content: HARMLESS
    , "content")
    "and we follow an object with bad content": badFollow(
      objectType: "person"
      id: "urn:uuid:3198b87e-3293-11e2-99c3-0024beb67924"
      content: DANGEROUS
    , "content")
    "and we follow an object with good summary": goodFollow(
      objectType: "person"
      id: "urn:uuid:31995450-3293-11e2-a166-0024beb67924"
      summary: HARMLESS
    , "summary")
    "and we follow an object with bad summary": badFollow(
      objectType: "person"
      id: "urn:uuid:3199f00e-3293-11e2-a5ac-0024beb67924"
      summary: DANGEROUS
    , "summary")
    "and we follow an object with a private member": privateFollow(
      objectType: "person"
      id: "urn:uuid:75f81018-36ae-11e2-ad19-70f1a154e1aa"
      _user: true
      summary: HARMLESS
    , "_user")

suite["export"] module
