# user-list-test.js
#
# Test the API for the global list of registered users
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
fs = require("fs")
path = require("path")
querystring = require("querystring")
OAuth = require("oauth").OAuth
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
setupApp = oauthutil.setupApp
suite = vows.describe("user list API")
tc = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json")))
invert = (callback) ->
  (err) ->
    if err
      callback null
    else
      callback new Error("Unexpected success")

assertGoodUser = (user) ->
  assert.include user, "nickname"
  assert.include user, "published"
  assert.include user, "updated"
  assert.include user, "profile"
  assert.include user, "token"
  assert.include user, "secret"
  assert.isObject user.profile
  assert.include user.profile, "id"
  assert.include user.profile, "objectType"
  assert.equal user.profile.objectType, "person"

register = (cl, params, callback) ->
  httputil.postJSON "http://localhost:4815/api/users",
    consumer_key: cl.client_id
    consumer_secret: cl.client_secret
  , params, callback

registerSucceed = (params) ->
  topic: (cl) ->
    register cl, params, @callback

  "it works": (err, user, resp) ->
    assert.ifError err
    assert.isObject user

  "results are correct": (err, user, resp) ->
    assertGoodUser user

registerFail = (params) ->
  topic: (cl) ->
    register cl, params, invert(@callback)

  "it fails correctly": (err) ->
    assert.ifError err

doubleRegisterSucceed = (first, second) ->
  topic: (cl) ->
    user1 = undefined
    user2 = undefined
    cb = @callback
    Step (->
      register cl, first, this
    ), ((err, doc, res) ->
      throw err  if err
      user1 = doc
      register cl, second, this
    ), ((err, doc, res) ->
      throw err  if err
      user2 = doc
      this null
    ), (err) ->
      if err
        cb err, null
      else
        cb null, user1, user2


  "it works": (err, user1, user2) ->
    assert.ifError err

  "user1 is correct": (err, user1, user2) ->
    assertGoodUser user1

  "user2 is correct": (err, user1, user2) ->
    assertGoodUser user2

doubleRegisterFail = (first, second) ->
  topic: (cl) ->
    cb = @callback
    Step (->
      register cl, first, this
    ), ((err, doc, res) ->
      if err
        cb err
        return
      register cl, second, this
    ), (err, doc, res) ->
      if err
        cb null
      else
        cb new Error("Unexpected success")


  "it fails correctly": (err) ->
    assert.ifError err

suite.addBatch "When we set up the app":
  topic: ->
    cb = @callback
    setupApp cb

  teardown: (app) ->
    app.close()  if app and app.close

  "it works": (err, app) ->
    assert.ifError err

  "and we check the user list endpoint":
    topic: ->
      httputil.options "localhost", 4815, "/api/users", @callback

    "it exists": (err, allow, res, body) ->
      assert.ifError err
      assert.equal res.statusCode, 200

    "it supports GET": (err, allow, res, body) ->
      assert.include allow, "GET"

    "it supports POST": (err, allow, res, body) ->
      assert.include allow, "POST"

  "and we try to register a user with no OAuth credentials":
    topic: ->
      cb = @callback
      httputil.postJSON "http://localhost:4815/api/users", {},
        nickname: "nocred"
        password: "nobadge"
      , (err, body, res) ->
        if err and err.statusCode is 401
          cb null
        else if err
          cb err
        else
          cb new Error("Unexpected success")


    "it fails correctly": (err) ->
      assert.ifError err

  "and we create a client using the api":
    topic: ->
      cb = @callback
      httputil.post "localhost", 4815, "/api/client/register",
        type: "client_associate"
      , (err, res, body) ->
        cl = undefined
        if err
          cb err, null
        else
          try
            cl = JSON.parse(body)
            cb null, cl
          catch err
            cb err, null


    "it works": (err, cl) ->
      assert.ifError err
      assert.isObject cl
      assert.isString cl.client_id
      assert.isString cl.client_secret

    "and we register a user with nickname and password": registerSucceed(
      nickname: "withcred"
      password: "very!secret"
    )
    "and we register a user with nickname and no password": registerFail(nickname: "nopass")
    "and we register a user with password and no nickname": registerFail(password: "too+secret")
    "and we register a user with a short password": registerFail(
      nickname: "shorty"
      password: "carpet"
    )
    "and we register a user with an all-alpha password": registerFail(
      nickname: "allalpha"
      password: "carpeted"
    )
    "and we register a user with an all-numeric password": registerFail(
      nickname: "allnumeric"
      password: "12345678"
    )
    "and we register a user with a well-known bad password": registerFail(
      nickname: "unoriginal"
      password: "rush2112"
    )
    "and we register a user with no data": registerFail({})
    "and we register two unrelated users": doubleRegisterSucceed(
      nickname: "able"
      password: "i-sure-am"
    ,
      nickname: "baker"
      password: "flour'n'water"
    )
    "and we register two users with the same nickname": doubleRegisterFail(
      nickname: "charlie"
      password: "parker69"
    ,
      nickname: "charlie"
      password: "mccarthy69"
    )
    "and we try to register with URL-encoded params":
      topic: (cl) ->
        oa = undefined
        toSend = undefined
        cb = @callback
        # request endpoint N/A for 2-legged OAuth
        # access endpoint N/A for 2-legged OAuth
        oa = new OAuth(null, null, cl.client_id, cl.client_secret, "1.0", null, "HMAC-SHA1", null, # nonce size; use default
          "User-Agent": "pump.io/0.2.0-alpha.1"
        )
        toSend = querystring.stringify(
          nickname: "delta"
          password: "dawn"
        )
        oa.post "http://localhost:4815/api/users", null, null, toSend, "application/x-www-form-urlencoded", (err, data, response) ->
          if err
            cb null
          else
            cb new Error("Unexpected success")


      "it fails correctly": (err) ->
        assert.ifError err

suite.addBatch "When we set up the app":
  topic: ->
    cb = @callback
    setupApp cb

  teardown: (app) ->
    app.close()

  "it works": (err, app) ->
    assert.ifError err

  "and we create a client using the api":
    topic: ->
      cb = @callback
      httputil.post "localhost", 4815, "/api/client/register",
        type: "client_associate"
      , (err, res, body) ->
        cl = undefined
        if err
          cb err, null
        else
          try
            cl = JSON.parse(body)
            cb null, cl
          catch err
            cb err, null


    "it works": (err, cl) ->
      assert.ifError err
      assert.isObject cl
      assert.isString cl.client_id
      assert.isString cl.client_secret

    "and we get an empty user list":
      topic: (cl) ->
        cb = @callback
        httputil.getJSON "http://localhost:4815/api/users",
          consumer_key: cl.client_id
          consumer_secret: cl.client_secret
        , (err, coll, resp) ->
          cb err, coll


      "it works": (err, collection) ->
        assert.ifError err

      "it has the right top-level properties": (err, collection) ->
        assert.isObject collection
        assert.include collection, "displayName"
        assert.isString collection.displayName
        assert.include collection, "id"
        assert.isString collection.id
        assert.include collection, "objectTypes"
        assert.isArray collection.objectTypes
        assert.lengthOf collection.objectTypes, 1
        assert.include collection.objectTypes, "user"
        assert.include collection, "totalItems"
        assert.isNumber collection.totalItems
        assert.include collection, "items"
        assert.isArray collection.items

      "it is empty": (err, collection) ->
        assert.equal collection.totalItems, 0
        assert.isEmpty collection.items

      "and we add a user":
        topic: (ignore, cl) ->
          cb = @callback
          register cl,
            nickname: "echo"
            password: "echo!echo!"
          , (err, body, res) ->
            if err
              cb err, null
            else
              httputil.getJSON "http://localhost:4815/api/users",
                consumer_key: cl.client_id
                consumer_secret: cl.client_secret
              , (err, coll, resp) ->
                cb err, coll



        "it works": (err, collection) ->
          assert.ifError err

        "it has the right top-level properties": (err, collection) ->
          assert.isObject collection
          assert.include collection, "displayName"
          assert.isString collection.displayName
          assert.include collection, "id"
          assert.isString collection.id
          assert.include collection, "objectTypes"
          assert.isArray collection.objectTypes
          assert.lengthOf collection.objectTypes, 1
          assert.include collection.objectTypes, "user"
          assert.include collection, "totalItems"
          assert.isNumber collection.totalItems
          assert.include collection, "items"
          assert.isArray collection.items

        "it has one element": (err, collection) ->
          assert.equal collection.totalItems, 1
          assert.lengthOf collection.items, 1

        "it has a valid user": (err, collection) ->
          user = collection.items[0]
          assert.include user, "nickname"
          assert.include user, "published"
          assert.include user, "updated"
          assert.include user, "profile"
          assert.isObject user.profile
          assert.include user.profile, "id"
          assert.include user.profile, "objectType"
          assert.equal user.profile.objectType, "person"

        "it has our valid user": (err, collection) ->
          user = collection.items[0]
          assert.equal user.nickname, "echo"

        "and we add a few more users":
          topic: (ignore1, ignore2, cl) ->
            cb = @callback
            Step (->
              i = undefined
              group = @group()
              i = 0 # have 1 already, total = 50
              while i < 49
                register cl,
                  nickname: "foxtrot" + i
                  password: "a*bad*pass*" + i
                , group()
                i++
            ), ((err) ->
              throw err  if err
              httputil.getJSON "http://localhost:4815/api/users",
                consumer_key: cl.client_id
                consumer_secret: cl.client_secret
              , this
            ), (err, collection, resp) ->
              if err
                cb err, null
              else
                cb null, collection


          "it works": (err, collection) ->
            assert.ifError err

          "it has the right top-level properties": (err, collection) ->
            assert.isObject collection
            assert.include collection, "displayName"
            assert.isString collection.displayName
            assert.include collection, "id"
            assert.isString collection.id
            assert.include collection, "objectTypes"
            assert.isArray collection.objectTypes
            assert.lengthOf collection.objectTypes, 1
            assert.include collection.objectTypes, "user"
            assert.include collection, "totalItems"
            assert.isNumber collection.totalItems
            assert.include collection, "items"
            assert.isArray collection.items

          "it has the right number of elements": (err, collection) ->
            assert.equal collection.totalItems, 50
            assert.lengthOf collection.items, 20

          "it has the navigation links": (err, collection) ->
            assert.ifError err
            assert.isObject collection
            assert.isObject collection.links
            assert.isObject collection.links.next
            assert.isObject collection.links.prev

          "there are no duplicates": (err, collection) ->
            i = undefined
            seen = {}
            items = collection.items
            i = 0
            while i < items.length
              assert.isUndefined seen[items[i].nickname]
              seen[items[i].nickname] = true
              i++

          "and we fetch all users":
            topic: (ignore1, ignore2, ignore3, cl) ->
              cb = @callback
              httputil.getJSON "http://localhost:4815/api/users?count=50",
                consumer_key: cl.client_id
                consumer_secret: cl.client_secret
              , cb

            "it works": (err, collection) ->
              assert.ifError err

            "it has the right top-level properties": (err, collection) ->
              assert.isObject collection
              assert.include collection, "displayName"
              assert.isString collection.displayName
              assert.include collection, "id"
              assert.isString collection.id
              assert.include collection, "objectTypes"
              assert.isArray collection.objectTypes
              assert.lengthOf collection.objectTypes, 1
              assert.include collection.objectTypes, "user"
              assert.include collection, "totalItems"
              assert.isNumber collection.totalItems
              assert.include collection, "items"
              assert.isArray collection.items

            "it has the right number of elements": (err, collection) ->
              assert.equal collection.totalItems, 50
              assert.lengthOf collection.items, 50

            "there are no duplicates": (err, collection) ->
              i = undefined
              seen = {}
              items = collection.items
              i = 0
              while i < items.length
                assert.isUndefined seen[items[i].nickname]
                seen[items[i].nickname] = true
                i++

          "and we fetch all users in groups of 10":
            topic: (ignore1, ignore2, ignore3, cl) ->
              cb = @callback
              Step (->
                i = undefined
                group = @group()
                i = 0
                while i < 50
                  httputil.getJSON "http://localhost:4815/api/users?offset=" + i + "&count=10",
                    consumer_key: cl.client_id
                    consumer_secret: cl.client_secret
                  , group()
                  i += 10
              ), (err, collections) ->
                j = undefined
                chunks = []
                if err
                  cb err, null
                else
                  j = 0
                  while j < collections.length
                    chunks[j] = collections[j].items
                    j++
                  cb null, chunks


            "it works": (err, chunks) ->
              assert.ifError err

            "it has the right number of elements": (err, chunks) ->
              i = undefined
              assert.lengthOf chunks, 5
              i = 0
              while i < chunks.length
                assert.lengthOf chunks[i], 10
                i++

            "there are no duplicates": (err, chunks) ->
              i = undefined
              j = undefined
              seen = {}
              i = 0
              while i < chunks.length
                j = 0
                while j < chunks[i].length
                  assert.isUndefined seen[chunks[i][j].nickname]
                  seen[chunks[i][j].nickname] = true
                  j++
                i++

          "and we fetch all users with the navigation links":
            topic: (ignore1, ignore2, ignore3, cl) ->
              cb = @callback
              all = []
              Step (->
                httputil.getJSON "http://localhost:4815/api/users",
                  consumer_key: cl.client_id
                  consumer_secret: cl.client_secret
                , this
              ), ((err, body, resp) ->
                throw err  if err
                all = all.concat(body.items)
                httputil.getJSON body.links.next.href,
                  consumer_key: cl.client_id
                  consumer_secret: cl.client_secret
                , this
              ), ((err, body, resp) ->
                throw err  if err
                all = all.concat(body.items)
                httputil.getJSON body.links.next.href,
                  consumer_key: cl.client_id
                  consumer_secret: cl.client_secret
                , this
              ), (err, body, resp) ->
                if err
                  cb err, null
                else
                  all = all.concat(body.items)
                  cb null, all


            "it works": (err, users) ->
              assert.ifError err

            "it has the right number of elements": (err, users) ->
              assert.ifError err
              assert.lengthOf users, 50

            "there are no duplicates": (err, users) ->
              i = undefined
              j = undefined
              seen = {}
              assert.ifError err
              i = 0
              while i < users.length
                assert.isUndefined seen[users[i].nickname]
                seen[users[i].nickname] = true
                i++

suite["export"] module
