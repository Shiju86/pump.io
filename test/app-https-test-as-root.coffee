# app-https-test-as-root.js
#
# Test running the app over HTTPS
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
fs = require("fs")
path = require("path")
databank = require("databank")
Step = require("step")
http = require("http")
https = require("https")
urlparse = require("url").parse
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
xrdutil = require("./lib/xrd")
suite = vows.describe("smoke test app interface over https")
tc = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json")))
clientCred = (cl) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret

makeCred = (cl, pair) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret
  token: pair.token
  token_secret: pair.token_secret

httpsURL = (url) ->
  parts = urlparse(url)
  parts.protocol is "https:"


# hostmeta links
hostmeta = links: [
  rel: "lrdd"
  type: "application/xrd+xml"
  template: /{uri}/
,
  rel: "lrdd"
  type: "application/json"
  template: /{uri}/
,
  rel: "registration_endpoint"
  href: "https://secure.localhost/api/client/register"
,
  rel: "dialback"
  href: "https://secure.localhost/api/dialback"
]
webfinger = links: [
  rel: "http://webfinger.net/rel/profile-page"
  type: "text/html"
  href: "https://secure.localhost/caterpillar"
,
  rel: "activity-inbox"
  href: "https://secure.localhost/api/user/caterpillar/inbox"
,
  rel: "activity-outbox"
  href: "https://secure.localhost/api/user/caterpillar/feed"
,
  rel: "dialback"
  href: "https://secure.localhost/api/dialback"
]
suite.addBatch "When we makeApp()":
  topic: ->
    config =
      port: 443
      hostname: "secure.localhost"
      key: path.join(__dirname, "data", "secure.localhost.key")
      cert: path.join(__dirname, "data", "secure.localhost.crt")
      driver: tc.driver
      params: tc.params
      nologger: true
      sockjs: false

    makeApp = require("../lib/app").makeApp
    process.env.NODE_ENV = "test"
    makeApp config, @callback

  "it works": (err, app) ->
    assert.ifError err
    assert.isObject app

  "and we app.run()":
    topic: (app) ->
      cb = @callback
      app.run (err) ->
        if err
          cb err, null
        else
          cb null, app


    teardown: (app) ->
      app.close()  if app and app.close

    "it works": (err, app) ->
      assert.ifError err

    "app is listening on correct port": (err, app) ->
      addr = app.address()
      assert.equal addr.port, 443

    "and we GET the host-meta file": xrdutil.xrdContext("https://secure.localhost/.well-known/host-meta", hostmeta)
    "and we GET the host-meta.json file": xrdutil.jrdContext("https://secure.localhost/.well-known/host-meta.json", hostmeta)
    "and we register a new client":
      topic: ->
        oauthutil.newClient "secure.localhost", 443, @callback

      "it works": (err, cred) ->
        assert.ifError err
        assert.isObject cred
        assert.include cred, "client_id"
        assert.include cred, "client_secret"
        assert.include cred, "expires_at"

      "and we register a new user":
        topic: (cl) ->
          oauthutil.register cl, "caterpillar", "mush+room", "secure.localhost", 443, @callback

        "it works": (err, user) ->
          assert.ifError err
          assert.isObject user

        "and we test the lrdd endpoint": xrdutil.xrdContext("https://secure.localhost/api/lrdd?uri=caterpillar@secure.localhost", webfinger)
        "and we test the lrdd.json endpoint": xrdutil.jrdContext("https://secure.localhost/api/lrdd.json?uri=caterpillar@secure.localhost", webfinger)
        "and we get the user":
          topic: (user, cl) ->
            url = "https://secure.localhost/api/user/caterpillar"
            httputil.getJSON url, clientCred(cl), @callback

          "it works": (err, body, resp) ->
            assert.ifError err
            assert.isObject body

          "the links look correct": (err, body, resp) ->
            assert.ifError err
            assert.isObject body
            assert.isObject body.profile
            assert.equal body.profile.id, "acct:caterpillar@secure.localhost"
            assert.equal body.profile.url, "https://secure.localhost/caterpillar"
            assert.isTrue httpsURL(body.profile.links.self.href)
            assert.isTrue httpsURL(body.profile.links["activity-inbox"].href)
            assert.isTrue httpsURL(body.profile.links["activity-outbox"].href)
            assert.isTrue httpsURL(body.profile.followers.url)
            assert.isTrue httpsURL(body.profile.following.url)
            assert.isTrue httpsURL(body.profile.lists.url)
            assert.isTrue httpsURL(body.profile.favorites.url)

        "and we get a new request token":
          topic: (user, cl) ->
            oauthutil.requestToken cl, "secure.localhost", 443, @callback

          "it works": (err, rt) ->
            assert.ifError err
            assert.isObject rt

          "and we authorize the request token":
            topic: (rt, user, cl) ->
              oauthutil.authorize cl, rt,
                nickname: "caterpillar"
                password: "mush+room"
              , "secure.localhost", 443, @callback

            "it works": (err, verifier) ->
              assert.ifError err
              assert.isString verifier

            "and we get an access token":
              topic: (verifier, rt, user, cl) ->
                oauthutil.redeemToken cl, rt, verifier, "secure.localhost", 443, @callback

              "it works": (err, pair) ->
                assert.ifError err
                assert.isObject pair

              "and the user posts a note":
                topic: (pair, verifier, rt, user, cl) ->
                  url = "https://secure.localhost/api/user/caterpillar/feed"
                  act =
                    verb: "post"
                    object:
                      objectType: "note"
                      content: "Who are you?"

                  httputil.postJSON url, makeCred(cl, pair), act, @callback

                "it works": (err, act) ->
                  assert.ifError err
                  assert.isObject act

                "URLs look correct": (err, act) ->
                  assert.ifError err
                  assert.isObject act
                  assert.isTrue httpsURL(act.url)
                  assert.isTrue httpsURL(act.object.links.self.href)
                  assert.isTrue httpsURL(act.object.likes.url)
                  assert.isTrue httpsURL(act.object.replies.url)
                  assert.isTrue httpsURL(act.actor.links.self.href)
                  assert.isTrue httpsURL(act.actor.links["activity-inbox"].href)
                  assert.isTrue httpsURL(act.actor.links["activity-outbox"].href)

suite["export"] module
