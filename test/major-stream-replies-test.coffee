# major-stream-replies-test.js
#
# Test that objects have "replies" stream in */major streams
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
http = require("http")
OAuth = require("oauth").OAuth
Browser = require("zombie")
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
setupApp = oauthutil.setupApp
newClient = oauthutil.newClient
register = oauthutil.register
accessToken = oauthutil.accessToken
newCredentials = oauthutil.newCredentials
newPair = oauthutil.newPair
makeCred = (cl, pair) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret
  token: pair.token
  token_secret: pair.token_secret

suite = vows.describe("Test replies items in major streams and favorites")
goodObjects = (err, feed) ->
  assert.ifError err
  assert.isObject feed
  assert.include feed, "items"
  assert.isArray feed.items
  assert.lengthOf feed.items, 20
  _.each feed.items, (object) ->
    assert.isObject object
    assert.include object, "objectType"
    assert.equal object.objectType, "note"
    assert.include object, "replies"
    assert.isObject object.replies
    assert.include object.replies, "items"
    assert.isArray object.replies.items


goodActivities = (err, feed) ->
  assert.ifError err
  assert.isObject feed
  assert.include feed, "items"
  assert.isArray feed.items
  assert.lengthOf feed.items, 20
  _.each feed.items, (activity, i) ->
    assert.isObject activity
    assert.include activity, "object"
    assert.isObject activity.object
    assert.include activity.object, "replies"
    assert.isObject activity.object.replies
    assert.include activity.object.replies, "items"
    assert.isArray activity.object.replies.items
    assert.lengthOf activity.object.replies.items, 4


sameUser = (url, objects) ->
  ctx =
    topic: (pair1, pair2, cl) ->
      callback = @callback
      cred = makeCred(cl, pair1)
      Step (->
        httputil.getJSON url, cred, this
      ), (err, feed, response) ->
        if err
          callback err, null
        else
          callback null, feed


    "it works": (err, feed) ->
      assert.ifError err
      assert.isObject feed

  if objects
    ctx["all objects have 'replies' feed with 'items' property"] = goodObjects
  else
    ctx["all objects have 'replies' feed with 'items' property"] = goodActivities
  ctx

justClient = (url, objects) ->
  ctx =
    topic: (pair1, pair2, cl) ->
      callback = @callback
      cred =
        consumer_key: cl.client_id
        consumer_secret: cl.client_secret

      Step (->
        httputil.getJSON url, cred, this
      ), (err, feed, response) ->
        if err
          callback err, null
        else
          callback null, feed


    "it works": (err, feed) ->
      assert.ifError err
      assert.isObject feed

  if objects
    ctx["all objects have 'replies' feed with 'items' property"] = goodObjects
  else
    ctx["all objects have 'replies' feed with 'items' property"] = goodActivities
  ctx

otherUser = (url, objects) ->
  ctx =
    topic: (pair1, pair2, cl) ->
      callback = @callback
      cred = makeCred(cl, pair2)
      Step (->
        httputil.getJSON url, cred, this
      ), (err, feed, response) ->
        if err
          callback err, null
        else
          callback null, feed


    "it works": (err, feed) ->
      assert.ifError err
      assert.isObject feed

  if objects
    ctx["all objects have 'replies' feed with 'items' property"] = goodObjects
  else
    ctx["all objects have 'replies' feed with 'items' property"] = goodActivities
  ctx


# A batch to test favoriting/unfavoriting objects
suite.addBatch "When we set up the app":
  topic: ->
    setupApp @callback

  teardown: (app) ->
    app.close()  if app and app.close

  "it works": (err, app) ->
    assert.ifError err

  "and we register a client":
    topic: ->
      newClient @callback

    "it works": (err, cl) ->
      assert.ifError err
      assert.isObject cl

    "and we register two users":
      topic: (cl) ->
        callback = @callback
        Step (->
          newPair cl, "gummy", "apple-pie!", @parallel()
          newPair cl, "curiouspete", "i|am|curious", @parallel()
        ), callback

      "it works": (err, pair1, pair2) ->
        assert.ifError err
        assert.isObject pair1
        assert.isObject pair2

      "and the first one posts a bunch of notes and likes them all and the second one replies to them all":
        topic: (pair1, pair2, cl) ->
          callback = @callback
          cred1 = makeCred(cl, pair1)
          cred2 = makeCred(cl, pair2)
          url1 = "http://localhost:4815/api/user/gummy/feed"
          url2 = "http://localhost:4815/api/user/curiouspete/feed"
          posts = undefined
          Step (->
            group = @group()
            _.times 20, (i) ->
              act =
                to: [pair1.user.profile]
                cc: [
                  objectType: "collection"
                  id: "http://activityschema.org/collection/public"
                ]
                verb: "post"
                object:
                  objectType: "note"
                  secretNumber: i
                  content: "Hello, world! " + i

              httputil.postJSON url1, cred1, act, group()

          ), ((err, results) ->
            group = @group()
            throw err  if err
            posts = results
            _.each posts, (post, i) ->
              act =
                verb: "favorite"
                object: post.object

              httputil.postJSON url1, cred1, act, group()

          ), ((err, likes) ->
            group = @group()
            throw err  if err
            _.each posts, (post, i) ->
              _.times 5, (i) ->
                act =
                  verb: "post"
                  object:
                    inReplyTo: post.object
                    objectType: "comment"
                    content: "Hello, back! " + i

                httputil.postJSON url2, cred2, act, group()


          ), (err, replies) ->
            if err
              callback err
            else
              callback null


        "it works": (err) ->
          assert.ifError err

        "and we check their major inbox with same user credentials": sameUser("http://localhost:4815/api/user/gummy/inbox/major")
        "and we check their major feed with same user credentials": sameUser("http://localhost:4815/api/user/gummy/feed/major")
        "and we check their major direct inbox with same user credentials": sameUser("http://localhost:4815/api/user/gummy/inbox/direct/major")
        "and we check their favorites with same user credentials": sameUser("http://localhost:4815/api/user/gummy/favorites", true)
        "and we check their major feed with client credentials": justClient("http://localhost:4815/api/user/gummy/feed/major")
        "and we check their favorites with client credentials": justClient("http://localhost:4815/api/user/gummy/favorites", true)
        "and we check the first user's major feed with different user credentials": otherUser("http://localhost:4815/api/user/gummy/feed/major")
        "and we check the first user's favorites with different user credentials": otherUser("http://localhost:4815/api/user/gummy/favorites", true)

suite["export"] module
