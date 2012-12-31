# generator-test.js
#
# Test generator for various write activities
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
newPair = oauthutil.newPair
newClient = oauthutil.newClient
ignore = (err) ->

suite = vows.describe("Activity generator attribute")
makeCred = (cl, pair) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret
  token: pair.token
  token_secret: pair.token_secret

clientCred = (cl) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret


# A batch for testing the read access to the API
suite.addBatch "When we set up the app":
  topic: ->
    setupApp @callback

  teardown: (app) ->
    app.close()  if app and app.close

  "it works": (err, app) ->
    assert.ifError err

  "and we register a new client":
    topic: ->
      cb = @callback
      params =
        application_name: "Generator Test"
        type: "client_associate"
        application_type: "native"

      Step (->
        httputil.post "localhost", 4815, "/api/client/register", params, this
      ), ((err, res, body) ->
        cl = undefined
        throw err  if err
        cl = JSON.parse(body)
        this null, cl
      ), cb

    "it works": (err, cl) ->
      assert.ifError err
      assert.isObject cl
      assert.include cl, "client_id"
      assert.include cl, "client_secret"

    "and we register a user":
      topic: (cl) ->
        newPair cl, "george", "sleeping1", @callback

      "it works": (err, pair) ->
        assert.ifError err
        assert.isObject pair

      "and we check the user's feed":
        topic: (pair, cl) ->
          cb = @callback
          cred = makeCred(cl, pair)
          url = "http://localhost:4815/api/user/george/feed"
          httputil.getJSON url, cred, (err, doc, resp) ->
            cb err, doc


        "registration activity has our generator": (err, doc) ->
          reg = undefined
          assert.ifError err
          assert.isObject doc
          assert.isArray doc.items
          reg = _.find(doc.items, (activity) ->
            activity.verb is "join"
          )
          assert.ok reg
          assert.isObject reg.generator
          assert.equal reg.generator.displayName, "Generator Test"

      "and we post a note":
        topic: (pair, cl) ->
          cb = @callback
          cred = makeCred(cl, pair)
          url = "http://localhost:4815/api/user/george/feed"
          act =
            verb: "post"
            object:
              objectType: "note"
              content: "Hello, world!"

          httputil.postJSON url, cred, act, (err, doc, resp) ->
            cb err, doc


        "the resulting activity has a generator": (err, act) ->
          assert.ifError err
          assert.isObject act
          assert.isObject act.generator
          assert.equal act.generator.displayName, "Generator Test"

      "and we post an activity to the minor feed":
        topic: (pair, cl) ->
          cb = @callback
          cred = makeCred(cl, pair)
          url = "http://localhost:4815/api/user/george/feed/minor"
          act =
            verb: "like"
            object:
              objectType: "note"
              id: "urn:uuid:995bb4c8-4870-11e2-b2db-2c8158efb9e9"
              content: "i love george"

          httputil.postJSON url, cred, act, (err, doc, resp) ->
            cb err, doc


        "the resulting activity has a generator": (err, act) ->
          assert.ifError err
          assert.isObject act
          assert.isObject act.generator
          assert.equal act.generator.displayName, "Generator Test"

      "and we post an activity to the major feed":
        topic: (pair, cl) ->
          cb = @callback
          cred = makeCred(cl, pair)
          url = "http://localhost:4815/api/user/george/feed/major"
          act =
            verb: "post"
            object:
              id: "urn:uuid:7045fd3c-4870-11e2-b038-2c8158efb9e9"
              objectType: "image"
              displayName: "rosy2.jpg"

          httputil.postJSON url, cred, act, (err, doc, resp) ->
            cb err, doc


        "the resulting activity has a generator": (err, act) ->
          assert.ifError err
          assert.isObject act
          assert.isObject act.generator
          assert.equal act.generator.displayName, "Generator Test"

      "and we follow someone by posting to the following list":
        topic: (pair, cl) ->
          cb = @callback
          cred = makeCred(cl, pair)
          url = "http://localhost:4815/api/user/george/following"
          person =
            objectType: "person"
            id: "urn:uuid:b7144562-486f-11e2-b1c7-2c8158efb9e9"
            displayName: "Cosmo G. Spacely"

          httputil.postJSON url, cred, person, (err, doc, resp) ->
            cb err


        "it works": (err) ->
          assert.ifError err

        "and we check the user's feed":
          topic: (pair, cl) ->
            cb = @callback
            cred = makeCred(cl, pair)
            url = "http://localhost:4815/api/user/george/feed"
            httputil.getJSON url, cred, (err, doc, resp) ->
              cb err, doc


          "follow activity has our generator": (err, doc) ->
            follow = undefined
            assert.ifError err
            assert.isObject doc
            assert.isArray doc.items
            follow = _.find(doc.items, (activity) ->
              activity.verb is "follow" and activity.object.id is "urn:uuid:b7144562-486f-11e2-b1c7-2c8158efb9e9"
            )
            assert.ok follow
            assert.isObject follow.generator
            assert.equal follow.generator.displayName, "Generator Test"

      "and we favorite something by posting to the favorites list":
        topic: (pair, cl) ->
          cb = @callback
          cred = makeCred(cl, pair)
          url = "http://localhost:4815/api/user/george/favorites"
          image =
            objectType: "image"
            id: "urn:uuid:298cd086-4871-11e2-adf2-2c8158efb9e9"
            displayName: "IMG3143.JPEG"

          httputil.postJSON url, cred, image, (err, doc, resp) ->
            cb err


        "it works": (err) ->
          assert.ifError err

        "and we check the user's feed":
          topic: (pair, cl) ->
            cb = @callback
            cred = makeCred(cl, pair)
            url = "http://localhost:4815/api/user/george/feed"
            httputil.getJSON url, cred, (err, doc, resp) ->
              cb err, doc


          "favorite activity has our generator": (err, doc) ->
            favorite = undefined
            assert.ifError err
            assert.isObject doc
            assert.isArray doc.items
            favorite = _.find(doc.items, (activity) ->
              activity.verb is "favorite" and activity.object.id is "urn:uuid:298cd086-4871-11e2-adf2-2c8158efb9e9"
            )
            assert.ok favorite
            assert.isObject favorite.generator
            assert.equal favorite.generator.displayName, "Generator Test"

      "and we update a note by PUT":
        topic: (pair, cl) ->
          cb = @callback
          cred = makeCred(cl, pair)
          url = "http://localhost:4815/api/user/george/feed"
          Step (->
            act =
              verb: "post"
              object:
                objectType: "note"
                content: "Stop this crazy thing."

            httputil.postJSON url, cred, act, this
          ), ((err, doc, resp) ->
            url = undefined
            obj = undefined
            throw err  if err
            obj = doc.object
            url = obj.links.self.href
            obj.content = "Stop this crazy thing!!!!!!!!!"
            httputil.putJSON url, cred, obj, this
          ), (err, doc, resp) ->
            cb err


        "it works": (err) ->
          assert.ifError err

        "and we check the user's feed":
          topic: (pair, cl) ->
            cb = @callback
            cred = makeCred(cl, pair)
            url = "http://localhost:4815/api/user/george/feed"
            httputil.getJSON url, cred, (err, doc, resp) ->
              cb err, doc


          "update activity has our generator": (err, doc) ->
            update = undefined
            assert.ifError err
            assert.isObject doc
            assert.isArray doc.items
            update = _.find(doc.items, (activity) ->
              activity.verb is "update" and activity.object.content is "Stop this crazy thing!!!!!!!!!"
            )
            assert.ok update
            assert.isObject update.generator
            assert.equal update.generator.displayName, "Generator Test"

      "and we delete a note by DELETE":
        topic: (pair, cl) ->
          cb = @callback
          cred = makeCred(cl, pair)
          url = "http://localhost:4815/api/user/george/feed"
          Step (->
            act =
              verb: "post"
              object:
                objectType: "note"
                content: "I quit."

            httputil.postJSON url, cred, act, this
          ), ((err, doc, resp) ->
            url = undefined
            obj = undefined
            throw err  if err
            obj = doc.object
            url = obj.links.self.href
            httputil.delJSON url, cred, this
          ), (err, doc, resp) ->
            cb err


        "it works": (err) ->
          assert.ifError err

        "and we check the user's feed":
          topic: (pair, cl) ->
            cb = @callback
            cred = makeCred(cl, pair)
            url = "http://localhost:4815/api/user/george/feed"
            httputil.getJSON url, cred, (err, doc, resp) ->
              cb err, doc


          "delete activity has our generator": (err, doc) ->
            del = undefined
            assert.ifError err
            assert.isObject doc
            assert.isArray doc.items
            del = _.find(doc.items, (activity) ->
              activity.verb is "delete"
            )
            assert.ok del
            assert.isObject del.generator
            assert.equal del.generator.displayName, "Generator Test"

      "and we add a person to a list by posting to the members feed":
        topic: (pair, cl) ->
          cb = @callback
          cred = makeCred(cl, pair)
          Step (->
            url = "http://localhost:4815/api/user/george/lists/person"
            httputil.getJSON url, cred, this
          ), ((err, doc, resp) ->
            list = undefined
            person = undefined
            throw err  if err
            list = _.find(doc.items, (item) ->
              item.displayName is "Family"
            )
            person =
              objectType: "person"
              id: "urn:uuid:2dbe56f6-4877-11e2-a117-2c8158efb9e9"
              displayName: "Elroy Jetson"

            httputil.postJSON list.members.url, cred, person, this
          ), (err, doc, resp) ->
            cb err


        "it works": (err) ->
          assert.ifError err

        "and we check the user's feed":
          topic: (pair, cl) ->
            cb = @callback
            cred = makeCred(cl, pair)
            url = "http://localhost:4815/api/user/george/feed"
            httputil.getJSON url, cred, (err, doc, resp) ->
              cb err, doc


          "add activity has our generator": (err, doc) ->
            add = undefined
            assert.ifError err
            assert.isObject doc
            assert.isArray doc.items
            add = _.find(doc.items, (activity) ->
              activity.verb is "add"
            )
            assert.ok add
            assert.isObject add.generator
            assert.equal add.generator.displayName, "Generator Test"

suite["export"] module
