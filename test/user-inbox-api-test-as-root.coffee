# user-inbox-api-test-as-root.js
#
# Test posting to the user inbox
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
http = require("http")
querystring = require("querystring")
_ = require("underscore")
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
newCredentials = oauthutil.newCredentials
newClient = oauthutil.newClient
dialbackApp = require("./lib/dialback").dialbackApp
setupApp = oauthutil.setupApp
clientCred = (cl) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret

assoc = (id, token, ts, callback) ->
  URL = "http://localhost:4815/api/client/register"
  requestBody = querystring.stringify(type: "client_associate")
  parseJSON = (err, response, data) ->
    obj = undefined
    if err
      callback err, null, null
    else
      try
        obj = JSON.parse(data)
        callback null, obj, response
      catch e
        callback e, null, null

  ts = Date.now()  unless ts
  httputil.dialbackPost URL, id, token, ts, requestBody, "application/x-www-form-urlencoded", parseJSON

suite = vows.describe("user inbox API")
suite.addBatch "When we set up the app":
  topic: ->
    app = undefined
    callback = @callback
    Step (->
      setupApp this
    ), ((err, result) ->
      throw err  if err
      app = result
      dialbackApp 80, "social.localhost", this
    ), (err, dbapp) ->
      if err
        callback err, null, null
      else
        callback err, app, dbapp


  teardown: (app, dbapp) ->
    app.close()
    dbapp.close()

  "and we register a new user":
    topic: ->
      newCredentials "louisck", "hilarious", @callback

    "it works": (err, cred) ->
      assert.ifError err
      assert.isObject cred

    "and we check the inbox endpoint": httputil.endpoint("/api/user/louisck/inbox", ["GET", "POST"])
    "and we post to the inbox without credentials":
      topic: ->
        act =
          actor:
            id: "acct:user1@social.localhost"
            objectType: "person"

          id: "http://social.localhost/activity/1"
          verb: "post"
          object:
            id: "http://social.localhost/note/1"
            objectType: "note"
            content: "Hello, world!"

        requestBody = JSON.stringify(act)
        reqOpts =
          host: "localhost"
          port: 4815
          path: "/api/user/louisck/inbox"
          method: "POST"
          headers:
            "Content-Type": "application/json"
            "Content-Length": requestBody.length
            "User-Agent": "activitypump-test/0.1.0dev"

        callback = @callback
        req = http.request(reqOpts, (res) ->
          body = ""
          res.setEncoding "utf8"
          res.on "data", (chunk) ->
            body = body + chunk

          res.on "error", (err) ->
            callback err, null, null

          res.on "end", ->
            callback null, res, body

        )
        req.on "error", (err) ->
          callback err, null, null

        req.write requestBody
        req.end()

      "and it fails correctly": (err, res, body) ->
        assert.ifError err
        assert.greater res.statusCode, 399
        assert.lesser res.statusCode, 500

    "and we post to the inbox with unattributed OAuth credentials":
      topic: ->
        callback = @callback
        Step (->
          newClient this
        ), ((err, cl) ->
          throw err  if err
          url = "http://localhost:4815/api/user/louisck/inbox"
          act =
            actor:
              id: "acct:user1@social.localhost"
              objectType: "person"

            id: "http://social.localhost/activity/2"
            verb: "post"
            object:
              id: "http://social.localhost/note/2"
              objectType: "note"
              content: "Hello again, world!"

          cred = clientCred(cl)
          httputil.postJSON url, cred, act, this
        ), (err, body, res) ->
          if err and err.statusCode is 401
            callback null
          else if err
            callback err
          else
            callback new Error("Unexpected success")


      "and it fails correctly": (err) ->
        assert.ifError err

    "and we post to the inbox with OAuth credentials for a host":
      topic: ->
        callback = @callback
        Step (->
          assoc "social.localhost", "VALID1", Date.now(), this
        ), ((err, cl) ->
          throw err  if err
          url = "http://localhost:4815/api/user/louisck/inbox"
          act =
            actor:
              id: "acct:user1@social.localhost"
              objectType: "person"

            id: "http://social.localhost/activity/3"
            verb: "post"
            object:
              id: "http://social.localhost/note/2"
              objectType: "note"
              content: "Hello again, world!"

          cred = clientCred(cl)
          httputil.postJSON url, cred, act, this
        ), (err, body, res) ->
          if err and err.statusCode is 401
            callback null
          else if err
            callback err
          else
            callback new Error("Unexpected success")


      "and it fails correctly": (err) ->
        assert.ifError err

    "and we post to the inbox with OAuth credentials for an unrelated webfinger":
      topic: ->
        callback = @callback
        Step (->
          assoc "user0@social.localhost", "VALID2", Date.now(), this
        ), ((err, cl) ->
          throw err  if err
          url = "http://localhost:4815/api/user/louisck/inbox"
          act =
            actor:
              id: "acct:user2@social.localhost"
              objectType: "person"

            id: "http://social.localhost/activity/4"
            verb: "post"
            object:
              id: "http://social.localhost/note/3"
              objectType: "note"
              content: "Hello again, world!"

          cred = clientCred(cl)
          httputil.postJSON url, cred, act, this
        ), (err, body, res) ->
          if err and err.statusCode is 400
            callback null
          else if err
            callback err
          else
            callback new Error("Unexpected success")


      "and it fails correctly": (err) ->
        assert.ifError err

    "and we post an activity to the inbox with OAuth credentials for the actor":
      topic: ->
        callback = @callback
        Step (->
          assoc "user3@social.localhost", "VALID1", Date.now(), this
        ), ((err, cl) ->
          throw err  if err
          url = "http://localhost:4815/api/user/louisck/inbox"
          act =
            actor:
              id: "acct:user3@social.localhost"
              objectType: "person"

            to: [
              objectType: "collection"
              id: "http://social.localhost/user/user2/followers"
            ]
            id: "http://social.localhost/activity/5"
            verb: "post"
            object:
              id: "http://social.localhost/note/3"
              objectType: "note"
              content: "Hello again, world!"

          cred = clientCred(cl)
          httputil.postJSON url, cred, act, this
        ), callback

      "it works": (err, act, resp) ->
        assert.ifError err
        assert.isObject act

      "and we check the user's inbox":
        topic: (act, resp, cred) ->
          callback = @callback
          url = "http://localhost:4815/api/user/louisck/inbox"
          httputil.getJSON url, cred, (err, feed, result) ->
            callback err, feed, act


        "it works": (err, feed, act) ->
          assert.ifError err
          assert.isObject feed

        "it includes our posted activity": (err, feed, act) ->
          assert.ifError err
          assert.isObject feed
          assert.include feed, "items"
          assert.isArray feed.items
          assert.lengthOf feed.items, 1
          assert.isObject feed.items[0]
          assert.equal feed.items[0].id, act.id

suite["export"] module
