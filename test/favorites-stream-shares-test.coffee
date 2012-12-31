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

suite = vows.describe("Test shares items in favorites stream")
haveShares = (feed) ->
  assert.include feed, "items"
  assert.isArray feed.items
  assert.lengthOf feed.items, 20
  _.each feed.items, (object) ->
    assert.isObject object
    assert.include object, "shares"
    assert.isObject object.shares
    assert.include object.shares, "totalItems"
    assert.include object.shares, "url"


correctShares = (feed) ->
  assert.include feed, "items"
  assert.isArray feed.items
  assert.lengthOf feed.items, 20
  _.each feed.items, (object) ->
    assert.isObject object
    assert.include object, "shares"
    assert.isObject object.shares
    assert.include object.shares, "totalItems"
    if object.secretNumber % 2
      assert.equal object.shares.totalItems, 1
    else
      assert.equal object.shares.totalItems, 0


haveShared = (feed) ->
  assert.include feed, "items"
  assert.isArray feed.items
  assert.lengthOf feed.items, 20
  _.each feed.items, (object) ->
    assert.isObject object
    assert.include object, "pump_io"
    assert.isObject object.pump_io
    assert.include object.pump_io, "shared"
    assert.isBoolean object.pump_io.shared


noShared = (feed) ->
  assert.include feed, "items"
  assert.isArray feed.items
  assert.lengthOf feed.items, 20
  _.each feed.items, (object) ->
    assert.isObject object
    assert.isFalse _.has(object, "pump_io") and _.has(object.pump_io, "shared")


sharedIs = (val) ->
  (feed) ->
    assert.include feed, "items"
    assert.isArray feed.items
    assert.lengthOf feed.items, 20
    _.each feed.items, (object) ->
      assert.isObject object
      assert.include object, "pump_io"
      assert.isObject object.pump_io
      assert.include object.pump_io, "shared"
      if object.secretNumber % 2
        assert.equal object.pump_io.shared, val
      else
        assert.equal object.pump_io.shared, false


sameUser = (url, objects) ->
  ctx =
    topic: (pair0, pair1, cl) ->
      callback = @callback
      cred = makeCred(cl, pair0)
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

    "and we examine the feed":
      topic: (feed) ->
        feed

      "all items have shares": haveShares
      "some items have non-empty shares": correctShares
      "all items have the shared flag": haveShared
      "all items have shared = false": sharedIs(false)

  ctx

justClient = (url, objects) ->
  ctx =
    topic: (pair0, pair1, cl) ->
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

    "and we examine the feed":
      topic: (feed) ->
        feed

      "all items have shares": haveShares
      "some items have non-empty shares": correctShares
      "no items have the shared flag": noShared

  ctx

otherUser = (url, objects) ->
  ctx =
    topic: (pair0, pair1, cl) ->
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

    "and we examine the feed":
      topic: (feed) ->
        feed

      "all items have shares": haveShares
      "some items have non-empty shares": correctShares
      "all items have the shared flag": haveShared
      "all items have correct shared value": sharedIs(true)

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
          newPair cl, "click", "don't drive like my brother", @parallel()
          newPair cl, "clack", "don't drive like *my* brother", @parallel()
        ), callback

      "it works": (err, pair0, pair1) ->
        assert.ifError err
        assert.isObject pair0
        assert.isObject pair1

      "and the first one posts a bunch of notes and the second one shares every other one":
        topic: (pair0, pair1, cl) ->
          callback = @callback
          cred0 = makeCred(cl, pair0)
          cred1 = makeCred(cl, pair1)
          url0 = "http://localhost:4815/api/user/click/feed"
          url1 = "http://localhost:4815/api/user/clack/feed"
          posts = undefined
          Step (->
            group = @group()
            _.times 20, (i) ->
              act =
                to: [pair0.user.profile]
                cc: [
                  objectType: "collection"
                  id: "http://activityschema.org/collection/public"
                ]
                verb: "post"
                object:
                  objectType: "note"
                  secretNumber: i
                  content: "Our fair city " + i

              httputil.postJSON url0, cred0, act, group()

          ), ((err, results) ->
            group = @group()
            throw err  if err
            posts = results
            _.each posts, (post, i) ->
              act =
                verb: "like"
                object: post.object

              httputil.postJSON url0, cred0, act, group()

          ), ((err, results) ->
            group = @group()
            throw err  if err
            _.each posts, (post, i) ->
              if i % 2
                act =
                  verb: "share"
                  object: post.object

                httputil.postJSON url1, cred1, act, group()

          ), (err, shares) ->
            if err
              callback err
            else
              callback null


        "it works": (err) ->
          assert.ifError err

        "and we check their major inbox with same user credentials": sameUser("http://localhost:4815/api/user/click/favorites")
        "and we check their major feed with client credentials": justClient("http://localhost:4815/api/user/click/favorites")
        "and we check the first user's major feed with different user credentials": otherUser("http://localhost:4815/api/user/click/favorites")

suite["export"] module
