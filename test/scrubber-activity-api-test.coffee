# scrubber-activity-api-test.js
#
# Test posting various bits of filthy HTML in hopes they can ruin someone's life
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

postActivity = (act) ->
  url = "http://localhost:4815/api/user/mickey/feed"
  topic: (cred) ->
    httputil.postJSON url, cred, act, @callback

  "it works": (err, result, response) ->
    assert.ifError err
    assert.isObject result

goodActivity = (act, property) ->
  compare = deepProperty(act, property)
  context = postActivity(act)
  context["it is unchanged"] = (err, result, response) ->
    assert.ifError err
    assert.isObject result
    assert.equal deepProperty(result, property), compare

  context

badActivity = (act, property) ->
  context = postActivity(act)
  context["it is defanged"] = (err, result, response) ->
    assert.ifError err
    assert.isObject result
    assert.equal deepProperty(result, property).indexOf("<script>"), -1

  context

updateActivity = (act, update) ->
  feed = "http://localhost:4815/api/user/mickey/feed"
  topic: (cred) ->
    callback = @callback
    Step (->
      httputil.postJSON feed, cred, act, this
    ), ((err, posted) ->
      url = undefined
      copied = undefined
      throw err  if err
      copied = _.extend(posted, update)
      url = posted.links.self.href
      httputil.putJSON url, cred, copied, this
    ), (err, updated) ->
      if err
        callback err, null
      else
        callback null, updated


  "it works": (err, result, response) ->
    assert.ifError err
    assert.isObject result

goodUpdate = (orig, update, property) ->
  compare = deepProperty(update, property)
  context = updateActivity(orig, update)
  context["it is unchanged"] = (err, result, response) ->
    assert.ifError err
    assert.isObject result
    assert.equal deepProperty(result, property), compare

  context

badUpdate = (orig, update, property) ->
  compare = deepProperty(update, property)
  context = updateActivity(orig, update)
  context["it is defanged"] = (err, result, response) ->
    assert.ifError err
    assert.isObject result
    assert.equal deepProperty(result, property).indexOf("<script>"), -1

  context

privateUpdate = (orig, update, property) ->
  context = updateActivity(orig, update)
  context["private property is ignored"] = (err, result, response) ->
    assert.ifError err
    assert.isObject result
    assert.isFalse _.has(result, property)

  context

suite = vows.describe("Scrubber activity API test")

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
      oauthutil.newCredentials "mickey", "pluto111", @callback

    "it works": (err, cred) ->
      assert.ifError err
      assert.isObject cred

    "and we post an activity with good content": goodActivity(
      verb: "post"
      content: HARMLESS
      object:
        objectType: "note"
        content: "Hello, world"
    , "content")
    "and we post an activity with bad content": badActivity(
      verb: "post"
      content: DANGEROUS
      object:
        objectType: "note"
        content: "Hello, world"
    , "content")
    "and we post an activity with good object content": goodActivity(
      verb: "post"
      object:
        objectType: "note"
        content: HARMLESS
    , "object.content")
    "and we post an activity with bad object content": badActivity(
      verb: "post"
      object:
        objectType: "note"
        content: DANGEROUS
    , "object.content")
    "and we post an activity with good target summary": goodActivity(
      verb: "post"
      object:
        objectType: "note"
        content: "Hello, world."

      target:
        objectType: "collection"
        summary: HARMLESS
    , "target.summary")
    "and we post an activity with bad target summary": badActivity(
      verb: "post"
      object:
        objectType: "note"
        content: "Hello, world."

      target:
        objectType: "collection"
        summary: DANGEROUS
    , "target.summary")
    "and we post an activity with bad generator summary":
      topic: (cred) ->
        url = "http://localhost:4815/api/user/mickey/feed"
        act =
          verb: "post"
          object:
            objectType: "note"
            content: "Hello, world."

          generator:
            objectType: "application"
            id: "urn:uuid:64ace17c-4f85-11e2-9e1e-70f1a154e1aa"
            summary: DANGEROUS

        httputil.postJSON url, cred, act, @callback

      "it works": (err, result, response) ->
        assert.ifError err
        assert.isObject result

      "and we examine the result":
        topic: (result) ->
          result

        "the generator is overwritten": (result) ->
          assert.isObject result.generator
          assert.notEqual result.generator.summary, DANGEROUS

    "and we post an activity with good provider summary": goodActivity(
      verb: "post"
      object:
        objectType: "note"
        content: "Hello, world."

      provider:
        objectType: "service"
        summary: HARMLESS
    , "provider.summary")
    "and we post an activity with bad provider summary": badActivity(
      verb: "post"
      object:
        objectType: "note"
        content: "Hello, world."

      provider:
        objectType: "service"
        summary: DANGEROUS
    , "provider.summary")
    "and we post an activity with good context summary": goodActivity(
      verb: "post"
      object:
        objectType: "note"
        content: "Hello, world."

      context:
        objectType: "event"
        summary: HARMLESS
    , "context.summary")
    "and we post an activity with bad context summary": badActivity(
      verb: "post"
      object:
        objectType: "note"
        content: "Hello, world."

      context:
        objectType: "event"
        summary: DANGEROUS
    , "context.summary")
    "and we post an activity with good source summary": goodActivity(
      verb: "post"
      object:
        objectType: "note"
        content: "Hello, world."

      source:
        objectType: "collection"
        summary: HARMLESS
    , "source.summary")
    "and we post an activity with bad source summary": badActivity(
      verb: "post"
      object:
        objectType: "note"
        content: "Hello, world."

      source:
        objectType: "collection"
        summary: DANGEROUS
    , "source.summary")
    "and we update an activity with good content": goodUpdate(
      verb: "post"
      object:
        objectType: "note"
        content: "Hello, world."
    ,
      content: HARMLESS
    , "content")
    "and we update an activity with bad content": badUpdate(
      verb: "post"
      object:
        objectType: "note"
        content: "Hello, world."
    ,
      content: DANGEROUS
    , "content")
    "and we update an activity with a private member": privateUpdate(
      verb: "post"
      object:
        objectType: "note"
        content: "Hello, world."
    ,
      _uuid: "EHLO endofline <BR><BR>"
    , "_uuid")

suite["export"] module
