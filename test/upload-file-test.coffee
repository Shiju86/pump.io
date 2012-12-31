# upload-file-test.js
#
# Test uploading a file to a server
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
os = require("os")
fs = require("fs")
path = require("path")
mkdirp = require("mkdirp")
rimraf = require("rimraf")
_ = require("underscore")
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
actutil = require("./lib/activity")
setupAppConfig = oauthutil.setupAppConfig
newCredentials = oauthutil.newCredentials
newPair = oauthutil.newPair
newClient = oauthutil.newClient
register = oauthutil.register
accessToken = oauthutil.accessToken
suite = vows.describe("upload file test")
makeCred = (cl, pair) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret
  token: pair.token
  token_secret: pair.token_secret

assertValidFeed = (feed) ->
  assert.include feed, "totalItems"
  assert.isNumber feed.totalItems
  assert.include feed, "url"
  assert.isString feed.url
  assert.include feed, "items"
  assert.isArray feed.items

suite.addBatch "When we create a temporary upload dir":
  topic: ->
    callback = @callback
    dirname = path.join(os.tmpDir(), "upload-file-test", "" + Date.now())
    mkdirp dirname, (err) ->
      if err
        callback err, null
      else
        callback null, dirname


  "it works": (err, dir) ->
    assert.ifError err
    assert.isString dir

  teardown: (dir) ->
    rimraf dir, (err) ->


  "and we set up the app":
    topic: (dir) ->
      setupAppConfig
        uploaddir: dir
      , @callback

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

      "and we create a new user":
        topic: (cl) ->
          newPair cl, "mike", "stormtroopers_hittin_the_ground", @callback

        "it works": (err, pair) ->
          assert.ifError err
          assert.isObject pair

        "and we check the uploads endpoint": httputil.endpoint("/api/user/mike/uploads", ["POST", "GET"])
        "and we get the uploads endpoint of a new user":
          topic: (pair, cl) ->
            cred = makeCred(cl, pair)
            callback = @callback
            url = "http://localhost:4815/api/user/mike/uploads"
            Step (->
              httputil.getJSON url, cred, this
            ), (err, feed, response) ->
              callback err, feed


          "it works": (err, feed) ->
            assert.ifError err
            assert.isObject feed

          "it is correct": (err, feed) ->
            assert.ifError err
            assert.isObject feed
            assertValidFeed feed

          "it is empty": (err, feed) ->
            assert.ifError err
            assert.isObject feed
            assert.equal feed.totalItems, 0
            assert.lengthOf feed.items, 0

          "and we upload a file":
            topic: (feed, pair, cl) ->
              cred = makeCred(cl, pair)
              callback = @callback
              url = "http://localhost:4815/api/user/mike/uploads"
              fileName = path.join(__dirname, "data", "image1.jpg")
              Step (->
                httputil.postFile url, cred, fileName, "image/jpeg", this
              ), (err, doc, response) ->
                callback err, doc


            "it works": (err, doc) ->
              assert.ifError err
              assert.isObject doc

            "it looks right": (err, doc) ->
              assert.ifError err
              assert.isObject doc
              assert.include doc, "objectType"
              assert.equal doc.objectType, "image"
              assert.include doc, "fullImage"
              assert.isObject doc.fullImage
              assert.include doc.fullImage, "url"
              assert.isString doc.fullImage.url
              assert.isFalse _.has(doc, "_slug")
              assert.isFalse _.has(doc, "_uuid")

            "and we get the file":
              topic: (doc, feed, pair, cl) ->
                cred = makeCred(cl, pair)
                callback = @callback
                url = doc.fullImage.url
                oa = undefined
                oa = httputil.newOAuth(url, cred)
                Step (->
                  oa.get url, cred.token, cred.token_secret, this
                ), (err, data, response) ->
                  callback err, data


              "it works": (err, data) ->
                assert.ifError err

            "and we get the uploads feed again":
              topic: (doc, feed, pair, cl) ->
                cred = makeCred(cl, pair)
                callback = @callback
                url = "http://localhost:4815/api/user/mike/uploads"
                Step (->
                  httputil.getJSON url, cred, this
                ), (err, feed, response) ->
                  callback err, feed, doc


              "it works": (err, feed, doc) ->
                assert.ifError err
                assert.isObject feed

              "it is correct": (err, feed, doc) ->
                assert.ifError err
                assert.isObject feed
                assertValidFeed feed

              "it has our upload": (err, feed, doc) ->
                assert.ifError err
                assert.isObject feed
                assert.equal feed.totalItems, 1
                assert.lengthOf feed.items, 1
                assert.equal feed.items[0].id, doc.id

            "and we post an activity with the upload as the object":
              topic: (upl, feed, pair, cl) ->
                cred = makeCred(cl, pair)
                callback = @callback
                url = "http://localhost:4815/api/user/mike/feed"
                act =
                  verb: "post"
                  object: upl

                Step (->
                  httputil.postJSON url, cred, act, this
                ), (err, doc, response) ->
                  callback err, doc


              "it works": (err, act) ->
                assert.ifError err
                assert.isObject act

      "and we register another user":
        topic: (cl) ->
          newPair cl, "tom", "pick*eat*rate", @callback

        "it works": (err, pair) ->
          assert.ifError err
          assert.isObject pair

        "and we upload a file as a Binary object":
          topic: (pair, cl) ->
            cred = makeCred(cl, pair)
            callback = @callback
            url = "http://localhost:4815/api/user/tom/uploads"
            fileName = path.join(__dirname, "data", "image2.jpg")
            Step (->
              fs.readFile fileName, this
            ), ((err, data) ->
              bin = undefined
              throw err  if err
              bin =
                length: data.length
                mimeType: "image/jpeg"

              bin.data = data.toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(RegExp("=", "g"), "")
              httputil.postJSON url, cred, bin, this
            ), (err, doc, result) ->
              if err
                callback err, null
              else
                callback null, doc


          "it works": (err, doc) ->
            assert.ifError err
            assert.isObject doc

          "it looks right": (err, doc) ->
            assert.ifError err
            assert.isObject doc
            assert.include doc, "objectType"
            assert.equal doc.objectType, "image"
            assert.include doc, "fullImage"
            assert.isObject doc.fullImage
            assert.include doc.fullImage, "url"
            assert.isString doc.fullImage.url
            assert.isFalse _.has(doc, "_slug")
            assert.isFalse _.has(doc, "_uuid")

suite["export"] module
