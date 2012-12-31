# user-stream-api-test.js
#
# Test user streams API
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
setupApp = oauthutil.setupApp
register = oauthutil.register
accessToken = oauthutil.accessToken
newCredentials = oauthutil.newCredentials
ignore = (err) ->

suite = vows.describe("User stream API test")
sizeFeed = (endpoint, size) ->
  topic: (cred) ->
    full = "http://localhost:4815" + endpoint
    callback = @callback
    httputil.getJSON full, cred, callback

  "it works": (err, feed, resp) ->
    assert.ifError err

  "it looks like a feed": (err, feed, resp) ->
    assert.ifError err
    assert.isObject feed
    assert.include feed, "totalItems"
    assert.include feed, "items"

  "it is empty": (err, feed, resp) ->
    assert.ifError err
    assert.isObject feed
    assert.include feed, "totalItems"
    assert.equal feed.totalItems, size
    assert.include feed, "items"
    assert.isArray feed.items
    assert.equal feed.items.length, size

emptyFeed = (endpoint) ->
  topic: (cred) ->
    full = "http://localhost:4815" + endpoint
    callback = @callback
    httputil.getJSON full, cred, callback

  "it works": (err, feed, resp) ->
    assert.ifError err

  "it looks like a feed": (err, feed, resp) ->
    assert.ifError err
    assert.isObject feed
    assert.include feed, "totalItems"
    assert.include feed, "items"

  "it is empty": (err, feed, resp) ->
    assert.ifError err
    assert.isObject feed
    assert.include feed, "totalItems"
    assert.equal feed.totalItems, 0
    assert.include feed, "items"
    assert.isEmpty feed.items


# A batch for testing the read access to the API
suite.addBatch "When we set up the app":
  topic: ->
    setupApp @callback

  teardown: (app) ->
    app.close()  if app and app.close

  "it works": (err, app) ->
    assert.ifError err

  "and we get new credentials":
    topic: ->
      newCredentials "bigredchicken", "bokbokbok!", @callback

    "it works": (err, cred) ->
      assert.ifError err
      assert.isObject cred
      assert.isString cred.consumer_key
      assert.isString cred.consumer_secret
      assert.isString cred.token
      assert.isString cred.token_secret

    "and we check the feed endpoint": httputil.endpoint("/api/user/bigredchicken/feed", ["GET", "POST"])
    "and we check the minor feed endpoint": httputil.endpoint("/api/user/bigredchicken/feed/minor", ["GET"])
    "and we check the major feed endpoint": httputil.endpoint("/api/user/bigredchicken/feed/major", ["GET"])
    "and we check the inbox endpoint": httputil.endpoint("/api/user/bigredchicken/inbox", ["GET", "POST"])
    "and we check the minor inbox endpoint": httputil.endpoint("/api/user/bigredchicken/inbox/minor", ["GET"])
    "and we check the major inbox endpoint": httputil.endpoint("/api/user/bigredchicken/inbox/major", ["GET"])
    "and we check the direct inbox endpoint": httputil.endpoint("/api/user/bigredchicken/inbox/direct", ["GET"])
    "and we check the direct minor inbox endpoint": httputil.endpoint("/api/user/bigredchicken/inbox/direct/minor", ["GET"])
    "and we check the direct major inbox endpoint": httputil.endpoint("/api/user/bigredchicken/inbox/direct/major", ["GET"])
    "and we get the feed of a new user": sizeFeed("/api/user/bigredchicken/feed", 5)
    "and we get the minor feed of a new user": sizeFeed("/api/user/bigredchicken/feed/minor", 5)
    "and we get the major feed of a new user": emptyFeed("/api/user/bigredchicken/feed/major")
    "and we get the inbox of a new user": sizeFeed("/api/user/bigredchicken/inbox", 6)
    "and we get the minor inbox of a new user": sizeFeed("/api/user/bigredchicken/inbox/minor", 5)
    "and we get the major inbox of a new user": sizeFeed("/api/user/bigredchicken/inbox/major", 1)
    "and we get the direct inbox of a new user": sizeFeed("/api/user/bigredchicken/inbox/direct", 1)
    "and we get the direct minor inbox of a new user": emptyFeed("/api/user/bigredchicken/inbox/direct/minor")
    "and we get the direct major inbox of a new user": sizeFeed("/api/user/bigredchicken/inbox/direct/major", 1)

  "and we get more new credentials":
    topic: ->
      newCredentials "dora", "v4m0nos!", @callback

    "it works": (err, cred) ->
      assert.ifError err
      assert.isObject cred
      assert.isString cred.consumer_key
      assert.isString cred.consumer_secret
      assert.isString cred.token
      assert.isString cred.token_secret

    "and we post a new activity":
      topic: (cred) ->
        cb = @callback
        act =
          verb: "post"
          object:
            objectType: "note"
            content: "Hello, world!"

        httputil.postJSON "http://localhost:4815/api/user/dora/feed", cred, act, (err, act, result) ->
          cb err, act


      "it works": (err, act) ->
        assert.ifError err

      "results look right": (err, act) ->
        assert.isObject act
        assert.include act, "id"
        assert.isString act.id
        assert.include act, "actor"
        assert.isObject act.actor
        assert.include act.actor, "id"
        assert.isString act.actor.id
        assert.include act, "verb"
        assert.isString act.verb
        assert.include act, "object"
        assert.isObject act.object
        assert.include act.object, "id"
        assert.isString act.object.id
        assert.include act, "published"
        assert.isString act.published
        assert.include act, "updated"
        assert.isString act.updated

      "and we read the feed":
        topic: (act, cred) ->
          cb = @callback
          httputil.getJSON "http://localhost:4815/api/user/dora/feed", cred, (err, newf) ->
            if err
              cb err
            else
              cb null,
                act: act
                feed: newf



        "it works": (err, res) ->
          assert.ifError err

        "it has the right members": (err, res) ->
          assert.isObject res
          assert.include res, "feed"
          feed = res.feed
          assert.include feed, "author"
          assert.include feed.author, "id"
          assert.include feed.author, "displayName"
          assert.include feed.author, "objectType"
          assert.include feed, "totalItems"
          assert.include feed, "items"
          assert.include feed, "displayName"
          assert.include feed, "id"
          assert.include feed, "objectTypes"
          assert.include feed.objectTypes, "activity"

        "it has six objects": (err, res) ->
          assert.isObject res
          assert.include res, "feed"
          feed = res.feed
          assert.equal feed.totalItems, 6
          assert.equal feed.items.length, 6

        "it has our activity": (err, res) ->
          assert.isObject res
          assert.include res, "feed"
          assert.include res, "act"
          feed = res.feed
          act = res.act
          assert.equal feed.items[0].id, act.id

      "and we read the inbox":
        topic: (act, cred) ->
          cb = @callback
          httputil.getJSON "http://localhost:4815/api/user/dora/inbox", cred, (err, newb) ->
            if err
              cb err
            else
              cb null,
                act: act
                inbox: newb



        "it works": (err, res) ->
          assert.ifError err

        "it has the right members": (err, res) ->
          assert.isObject res
          assert.include res, "inbox"
          inbox = res.inbox
          assert.include inbox, "author"
          assert.include inbox.author, "id"
          assert.include inbox.author, "displayName"
          assert.include inbox.author, "objectType"
          assert.include inbox, "totalItems"
          assert.include inbox, "items"
          assert.include inbox, "displayName"
          assert.include inbox, "id"
          assert.include inbox, "objectTypes"
          assert.include inbox.objectTypes, "activity"

        "it has seven items": (err, res) ->
          assert.isObject res
          assert.include res, "inbox"
          inbox = res.inbox
          assert.equal inbox.totalItems, 7
          assert.equal inbox.items.length, 7

        "it has our activity": (err, res) ->
          assert.isObject res
          assert.include res, "inbox"
          assert.include res, "act"
          inbox = res.inbox
          act = res.act
          assert.equal inbox.items[0].id, act.id


# Test some "bad" kinds of activity
suite.addBatch "When we set up the app":
  topic: ->
    setupApp @callback

  teardown: (app) ->
    app.close()  if app and app.close

  "it works": (err, app) ->
    assert.ifError err

  "and we get new credentials":
    topic: (app) ->
      newCredentials "diego", "to*the*rescue", @callback

    "it works": (err, cred) ->
      assert.ifError err
      assert.isObject cred
      assert.isString cred.consumer_key
      assert.isString cred.consumer_secret
      assert.isString cred.token
      assert.isString cred.token_secret

    "and we try to post an activity with a different actor":
      topic: (cred, app) ->
        cb = @callback
        act =
          actor:
            id: "urn:uuid:66822a4d-9f72-4168-8d5a-0b1319afeeb1"
            objectType: "person"
            displayName: "Not Diego"

          verb: "post"
          object:
            objectType: "note"
            content: "To the rescue!"

        httputil.postJSON "http://localhost:4815/api/user/diego/feed", cred, act, (err, feed, result) ->
          if err
            cb null
          else if result.statusCode < 400 or result.statusCode >= 500
            cb new Error("Unexpected result")
          else
            cb null


      "it fails correctly": (err) ->
        assert.ifError err

    "and we try to post an activity with no object":
      topic: (cred, app) ->
        cb = @callback
        act = verb: "noop"
        httputil.postJSON "http://localhost:4815/api/user/diego/feed", cred, act, (err, feed, result) ->
          if err
            cb null
          else if result.statusCode < 400 or result.statusCode >= 500
            cb new Error("Unexpected result")
          else
            cb null


      "it fails correctly": (err) ->
        assert.ifError err

    "and we try to post an activity as a different user":
      topic: (cred, app) ->
        cb = @callback
        cl =
          client_id: cred.consumer_key
          client_secret: cred.consumer_secret

        act =
          verb: "post"
          object:
            objectType: "note"
            content: "To the rescue!"

        Step (->
          register cl, "boots", "b4nanazz", this
        ), ((err, user) ->
          throw err  if err
          accessToken cl,
            nickname: "boots"
            password: "b4nanazz"
          , this
        ), (err, pair) ->
          nuke = undefined
          if err
            cb err
          else
            nuke = _(cred).clone()
            _(nuke).extend pair
            httputil.postJSON "http://localhost:4815/api/user/diego/feed", nuke, act, (err, feed, result) ->
              if err
                cb null
              else if result.statusCode < 400 or result.statusCode >= 500
                cb new Error("Unexpected result")
              else
                cb null



      "it fails correctly": (err) ->
        assert.ifError err

    "and we try to post an activity with a default verb":
      topic: (cred, app) ->
        cb = @callback
        act = object:
          objectType: "note"
          content: "Hello, llama!"

        httputil.postJSON "http://localhost:4815/api/user/diego/feed", cred, act, (err, posted, result) ->
          if err
            cb err, null
          else
            cb null, posted


      "it works": (err, act) ->
        assert.ifError err

      "it has the right verb": (err, act) ->
        assert.equal act.verb, "post"


# Test arguments to the feed
BASE = "http://localhost:4815/api/user/alicia/feed"
INBOX = "http://localhost:4815/api/user/alicia/inbox"
MAJORINBOX = "http://localhost:4815/api/user/alicia/inbox/major"
MAJOROUTBOX = "http://localhost:4815/api/user/alicia/feed/major"
justDoc = (callback) ->
  (err, doc, resp) ->
    callback err, doc

docPlus = (callback, plus) ->
  (err, doc, resp) ->
    callback err, doc, plus

getDoc = (url) ->
  (cred) ->
    httputil.getJSON url, cred, justDoc(@callback)

failDoc = (url) ->
  (cred) ->
    cb = @callback
    httputil.getJSON url, cred, (err, doc, resp) ->
      if err and err.statusCode and err.statusCode >= 400 and err.statusCode < 500
        cb null
      else if err
        cb err
      else
        cb new Error("Unexpected success")


cmpDoc = (url) ->
  (full, cred) ->
    httputil.getJSON url, cred, docPlus(@callback, full)

cmpBefore = (base, idx, count) ->
  (full, cred) ->
    id = full.items[idx].id
    url = base + "?before=" + id
    url = url + "&count=" + count  unless _(count).isUndefined()
    httputil.getJSON url, cred, docPlus(@callback, full)

cmpSince = (base, idx, count) ->
  (full, cred) ->
    id = full.items[idx].id
    url = base + "?since=" + id
    url = url + "&count=" + count  unless _(count).isUndefined()
    httputil.getJSON url, cred, docPlus(@callback, full)

itWorks = (err, doc) ->
  assert.ifError err, doc

itFails = (err) ->
  assert.ifError err

validForm = (count, total) ->
  (err, doc) ->
    assert.include doc, "author"
    assert.include doc.author, "id"
    assert.include doc.author, "displayName"
    assert.include doc.author, "objectType"
    assert.isFalse _.has(doc.author, "_user")
    assert.isFalse _.has(doc.author, "_uuid")
    assert.include doc, "totalItems"
    assert.include doc, "items"
    assert.include doc, "displayName"
    assert.include doc, "id"
    assert.include doc, "url"
    assert.equal doc.items.length, count  if _(count).isNumber()
    assert.equal doc.totalItems, total  if _(total).isNumber()
    assert.include doc, "links"
    assert.isObject doc.links
    assert.include doc.links, "self"
    assert.isObject doc.links.self
    assert.include doc.links.self, "href"
    assert.isString doc.links.self.href
    assert.include doc.links, "first"
    assert.isObject doc.links.first
    assert.include doc.links.first, "href"
    assert.isString doc.links.first.href
    if _(count).isNumber() and count isnt 0
      assert.include doc.links, "prev"
      assert.isObject doc.links.prev
      assert.include doc.links.prev, "href"
      assert.isString doc.links.prev.href

validData = (start, end) ->
  (err, doc, full) ->
    assert.deepEqual doc.items, full.items.slice(start, end)


# Workout a feed endpoint
workout = (endpoint, total) ->
  total = 105  unless total
  "and we get the default feed":
    topic: getDoc(endpoint)
    "it works": itWorks
    "it looks right": validForm(20, total)

  "and we get the full feed":
    topic: getDoc(endpoint + "?count=" + total)
    "it works": itWorks
    "it looks right": validForm(total, total)
    "and we get the feed with a non-zero offset":
      topic: cmpDoc(endpoint + "?offset=50")
      "it works": itWorks
      "it looks right": validForm(20, total)
      "it has the right data": validData(50, 70)

    "and we get the feed with a zero offset":
      topic: cmpDoc(endpoint + "?offset=0")
      "it works": itWorks
      "it looks right": validForm(20, total)
      "it has the right data": validData(0, 20)

    "and we get the feed with a non-zero offset and count":
      topic: cmpDoc(endpoint + "?offset=20&count=20")
      "it works": itWorks
      "it looks right": validForm(20, total)
      "it has the right data": validData(20, 40)

    "and we get the feed with a zero offset and count":
      topic: cmpDoc(endpoint + "?offset=0")
      "it works": itWorks
      "it looks right": validForm(20, total)
      "it has the right data": validData(0, 20)

    "and we get the feed with a non-zero count":
      topic: cmpDoc(endpoint + "?count=50")
      "it works": itWorks
      "it looks right": validForm(50, total)
      "it has the right data": validData(0, 50)

    "and we get the feed since a value":
      topic: cmpSince(endpoint, 25)
      "it works": itWorks
      "it looks right": validForm(20, total)
      "it has the right data": validData(5, 25)

    "and we get the feed before a value":
      topic: cmpBefore(endpoint, 25)
      "it works": itWorks
      "it looks right": validForm(20, total)
      "it has the right data": validData(26, 46)

    "and we get the feed since a small value":
      topic: cmpSince(endpoint, 5)
      "it works": itWorks
      "it looks right": validForm(5, total)
      "it has the right data": validData(0, 5)

    "and we get the feed before a big value":
      topic: cmpBefore(endpoint, 94)
      "it works": itWorks
      "it looks right": validForm(total - 95, total)
      "it has the right data": validData(95, total)

    "and we get the feed since a value with a count":
      topic: cmpSince(endpoint, 75, 50)
      "it works": itWorks
      "it looks right": validForm(50, total)
      "it has the right data": validData(25, 75)

    "and we get the feed before a value with a count":
      topic: cmpBefore(endpoint, 35, 50)
      "it works": itWorks
      "it looks right": validForm(50, total)
      "it has the right data": validData(36, 86)

    "and we get the feed since a value with a zero count":
      topic: cmpSince(endpoint, 30, 0)
      "it works": itWorks
      "it looks right": validForm(0, total)

    "and we get the feed before a value with a zero count":
      topic: cmpBefore(endpoint, 60, 0)
      "it works": itWorks
      "it looks right": validForm(0, total)

    "and we get the full feed by following 'next' links":
      topic: (full, cred) ->
        cb = @callback
        items = []
        addResultsOf = (url) ->
          httputil.getJSON url, cred, (err, doc, resp) ->
            if err
              cb err, null, null
            else
              if doc.items.length > 0
                items = items.concat(doc.items)
                if doc.links.next
                  addResultsOf doc.links.next.href
                else
                  cb null, items, full
              else
                cb null, items, full


        addResultsOf endpoint

      "it works": itWorks
      "it looks correct": (err, items, full) ->
        assert.isArray items
        assert.equal items.length, full.items.length
        assert.deepEqual items, full.items

  "and we get the feed with a negative count":
    topic: failDoc(endpoint + "?count=-30")
    "it fails correctly": itFails

  "and we get the feed with a negative offset":
    topic: failDoc(endpoint + "?offset=-50")
    "it fails correctly": itFails

  "and we get the feed with a zero offset and zero count":
    topic: getDoc(endpoint + "?offset=0&count=0")
    "it works": itWorks
    "it looks right": validForm(0, total)

  "and we get the feed with a non-zero offset and zero count":
    topic: getDoc(endpoint + "?offset=30&count=0")
    "it works": itWorks
    "it looks right": validForm(0, total)

  "and we get the feed with a non-integer count":
    topic: failDoc(endpoint + "?count=foo")
    "it fails correctly": itFails

  "and we get the feed with a non-integer offset":
    topic: failDoc(endpoint + "?offset=bar")
    "it fails correctly": itFails

  "and we get the feed with a too-large offset":
    topic: getDoc(endpoint + "?offset=200")
    "it works": itWorks
    "it looks right": validForm(0, total)

  "and we get the feed with a too-large count":
    topic: getDoc(endpoint + "?count=150")
    "it works": itWorks
    "it looks right": validForm(total, total)

  "and we get the feed with a disallowed count":
    topic: failDoc(endpoint + "?count=1000")
    "it fails correctly": itFails

  "and we get the feed before a nonexistent id":
    topic: failDoc(endpoint + "?before=" + encodeURIComponent("http://example.net/nonexistent"))
    "it fails correctly": itFails

  "and we get the feed since a nonexistent id":
    topic: failDoc(endpoint + "?since=" + encodeURIComponent("http://example.net/nonexistent"))
    "it fails correctly": itFails

suite.addBatch "When we set up the app":
  topic: ->
    setupApp @callback

  teardown: (app) ->
    app.close()  if app and app.close

  "it works": (err, app) ->
    assert.ifError err

  "and we get new credentials":
    topic: (app) ->
      newCredentials "alicia", "base*station", @callback

    "it works": (err, cred) ->
      assert.ifError err
      assert.isObject cred
      assert.isString cred.consumer_key
      assert.isString cred.consumer_secret
      assert.isString cred.token
      assert.isString cred.token_secret

    "and we post a bunch of major activities":
      topic: (cred) ->
        cb = @callback
        Step (->
          group = @group()
          i = undefined
          act =
            verb: "post"
            object:
              objectType: "note"
              content: "Hello, World!"

          newAct = undefined
          url = BASE
          i = 0
          while i < 100
            newAct = JSON.parse(JSON.stringify(act))
            newAct.object.content = "Hello, World #" + i + "!"
            httputil.postJSON url, cred, newAct, group()
            i++
        ), (err) ->
          cb err


      "it works": (err) ->
        assert.ifError err

      "and we workout the outbox": workout(BASE, 105)
      "and we workout the inbox": workout(INBOX, 102)
      "and we workout the major inbox": workout(MAJORINBOX, 105)
      "and we workout the major outbox": workout(MAJOROUTBOX, 100)
      "and we check the minor inbox": sizeFeed("/api/user/alicia/inbox/minor", 1)
      "and we check the direct inbox": sizeFeed("/api/user/alicia/inbox/direct", 1)
      "and we check the direct minor inbox": emptyFeed("/api/user/alicia/inbox/direct/minor")
      "and we check the direct major inbox": sizeFeed("/api/user/alicia/inbox/direct/major", 1)

  "and we get new credentials":
    topic: (app) ->
      newCredentials "benny", "my/guys!", @callback

    "it works": (err, cred) ->
      assert.ifError err
      assert.isObject cred
      assert.isString cred.consumer_key
      assert.isString cred.consumer_secret
      assert.isString cred.token
      assert.isString cred.token_secret

    "and we post a bunch of minor activities":
      topic: (cred) ->
        cb = @callback
        Step (->
          group = @group()
          i = undefined
          act =
            verb: "post"
            to: [
              id: "http://activityschema.org/collection/public"
              objectType: "collection"
            ]
            object:
              objectType: "comment"
              inReplyTo:
                id: "urn:uuid:79ce4946-0427-11e2-aa67-70f1a154e1aa"
                objectType: "image"

          newAct = undefined
          url = "http://localhost:4815/api/user/benny/feed"
          i = 0
          while i < 100
            newAct = JSON.parse(JSON.stringify(act))
            newAct.object.content = "I love it! " + i
            httputil.postJSON(url, cred, newAct, group())
            i++
        ), (err) ->
          cb err


      "it works": (err) ->
        assert.ifError err

      "and we work out the minor inbox": workout("http://localhost:4815/api/user/benny/inbox/minor", 105)
      "and we work out the minor outbox": workout("http://localhost:4815/api/user/benny/feed/minor", 105)
      "and we check the major inbox": sizeFeed("/api/user/benny/inbox/major", 1)
      "and we check the direct inbox": sizeFeed("/api/user/benny/inbox/direct", 1)
      "and we check the direct minor inbox": emptyFeed("/api/user/benny/inbox/direct/minor")
      "and we check the direct major inbox": sizeFeed("/api/user/benny/inbox/direct/major", 1)

  "and we post a lot of stuff from one user to another":
    topic: (app) ->
      Step (->
        newCredentials "isa", "really_smart", @parallel()
        newCredentials "tico", "drives-a-car", @parallel()
      ), @callback

    "it works": (err, cred1, cred2) ->
      assert.ifError err
      assert.isObject cred1
      assert.isObject cred2

    "and we post a bunch of major activities":
      topic: (cred1, cred2) ->
        cb = @callback
        Step (->
          group = @group()
          i = undefined
          act =
            verb: "post"
            to: [cred1.user.profile]
            object:
              objectType: "note"

          newAct = undefined
          url = "http://localhost:4815/api/user/tico/feed"
          i = 0
          while i < 100
            newAct = JSON.parse(JSON.stringify(act))
            newAct.object.content = "Hi there! " + i
            httputil.postJSON(url, cred2, newAct, group())
            i++
        ), (err) ->
          cb err


      "it works": (err) ->
        assert.ifError err

      "and we work out the direct inbox": workout("http://localhost:4815/api/user/isa/inbox/direct", 101)
      "and we work out the major direct inbox": workout("http://localhost:4815/api/user/isa/inbox/direct/major", 101)
      "and we check the minor direct inbox": emptyFeed("/api/user/isa/inbox/direct/minor")

  "and register a couple more users":
    topic: (app) ->
      Step (->
        newCredentials "backpack", "loaded|up", @parallel()
        newCredentials "map", "I'mtheMap", @parallel()
      ), @callback

    "it works": (err, cred1, cred2) ->
      assert.ifError err
      assert.isObject cred1
      assert.isObject cred2

    "and we post a bunch of major activities":
      topic: (cred1, cred2) ->
        cb = @callback
        Step (->
          group = @group()
          i = undefined
          act =
            verb: "post"
            to: [cred1.user.profile]
            object:
              objectType: "comment"
              inReplyTo:
                id: "urn:uuid:2435a836-042b-11e2-99dd-70f1a154e1aa"
                objectType: "video"

          newAct = undefined
          url = "http://localhost:4815/api/user/map/feed"
          i = 0
          while i < 100
            newAct = JSON.parse(JSON.stringify(act))
            newAct.object.content = "This is great! " + i
            httputil.postJSON(url, cred2, newAct, group())
            i++
        ), (err) ->
          cb err


      "it works": (err) ->
        assert.ifError err

      "and we work out the direct inbox": workout("http://localhost:4815/api/user/backpack/inbox/direct", 101)
      "and we work out the minor direct inbox": workout("http://localhost:4815/api/user/backpack/inbox/direct/minor", 100)
      "and we check the major direct inbox": sizeFeed("/api/user/backpack/inbox/direct/major", 1)

suite["export"] module
