# distributor-remote-test-as-root.js
#
# Test distribution to remote servers
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
urlparse = require("url").parse
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
newCredentials = oauthutil.newCredentials
newClient = oauthutil.newClient
pj = httputil.postJSON
gj = httputil.getJSON
dialbackApp = require("./lib/dialback").dialbackApp
setupApp = oauthutil.setupApp
suite = vows.describe("distributor remote test")
serverOf = (url) ->
  parts = urlparse(url)
  parts.hostname

suite.addBatch "When we set up two apps":
  topic: ->
    social = undefined
    photo = undefined
    callback = @callback
    Step (->
      setupApp 80, "social.localhost", @parallel()
      setupApp 80, "photo.localhost", @parallel()
    ), (err, social, photo) ->
      if err
        callback err, null, null
      else
        callback null, social, photo


  "it works": (err, social, photo) ->
    assert.ifError err

  teardown: (social, photo) ->
    social.close()  if social and social.close
    photo.close()  if photo and photo.close

  "and we register one user on each":
    topic: ->
      callback = @callback
      Step (->
        newCredentials "maven", "t4steful", "social.localhost", 80, @parallel()
        newCredentials "photog", "gritty*1", "photo.localhost", 80, @parallel()
      ), callback

    "it works": (err, cred1, cred2) ->
      assert.ifError err
      assert.isObject cred1
      assert.isObject cred2

    "and one user follows the other":
      topic: (cred1, cred2) ->
        url = "http://social.localhost/api/user/maven/feed"
        act =
          verb: "follow"
          object:
            id: "acct:photog@photo.localhost"
            objectType: "person"

        callback = @callback
        pj url, cred1, act, (err, body, resp) ->
          if err
            callback err, null
          else
            callback null, body


      "it works": (err, body) ->
        assert.ifError err
        assert.isObject body

      "and we wait a few seconds for delivery":
        topic: ->
          callback = @callback
          setTimeout (->
            callback null
          ), 5000

        "it works": (err) ->
          assert.ifError err

        "and we check the first user's following list":
          topic: (act, cred1, cred2) ->
            url = "http://social.localhost/api/user/maven/following"
            callback = @callback
            gj url, cred1, (err, body, resp) ->
              if err
                callback err, null
              else
                callback null, body


          "it works": (err, feed) ->
            assert.ifError err
            assert.isObject feed

          "it includes the second user": (err, feed) ->
            assert.ifError err
            assert.isObject feed
            assert.include feed, "items"
            assert.isArray feed.items
            assert.greater feed.items.length, 0
            assert.isObject feed.items[0]
            assert.include feed.items[0], "id"
            assert.equal feed.items[0].id, "acct:photog@photo.localhost"

        "and we check the second user's followers list":
          topic: (act, cred1, cred2) ->
            url = "http://photo.localhost/api/user/photog/followers"
            callback = @callback
            gj url, cred2, (err, body, resp) ->
              if err
                callback err, null
              else
                callback null, body


          "it works": (err, feed) ->
            maven = undefined
            assert.ifError err
            assert.isObject feed
            assert.include feed, "items"
            assert.isArray feed.items
            assert.greater feed.items.length, 0
            assert.isObject feed.items[0]
            maven = feed.items[0]
            assert.include maven, "id"
            assert.equal maven.id, "acct:maven@social.localhost"
            assert.include maven, "followers"
            assert.isObject maven.followers
            assert.include maven.followers, "url"
            assert.equal serverOf(maven.followers.url), "social.localhost"
            assert.include maven, "following"
            assert.isObject maven.following
            assert.include maven.following, "url"
            assert.equal serverOf(maven.following.url), "social.localhost"
            assert.include maven, "favorites"
            assert.isObject maven.favorites
            assert.include maven.favorites, "url"
            assert.equal serverOf(maven.favorites.url), "social.localhost"
            assert.include maven, "lists"
            assert.isObject maven.lists
            assert.include maven.lists, "url"
            assert.equal serverOf(maven.lists.url), "social.localhost"
            assert.include maven, "links"
            assert.isObject maven.links
            assert.include maven.links, "self"
            assert.isObject maven.links.self
            assert.include maven.links.self, "href"
            assert.equal serverOf(maven.links.self.href), "social.localhost"
            assert.include maven.links, "activity-inbox"
            assert.isObject maven.links["activity-inbox"]
            assert.include maven.links["activity-inbox"], "href"
            assert.equal serverOf(maven.links["activity-inbox"].href), "social.localhost"
            assert.include maven.links, "self"
            assert.isObject maven.links["activity-outbox"]
            assert.include maven.links["activity-outbox"], "href"
            assert.equal serverOf(maven.links["activity-outbox"].href), "social.localhost"

        "and we check the second user's inbox":
          topic: (act, cred1, cred2) ->
            url = "http://photo.localhost/api/user/photog/inbox"
            callback = @callback
            gj url, cred2, (err, feed, resp) ->
              if err
                callback err, null, null
              else
                callback null, feed, act


          "it works": (err, feed, act) ->
            assert.ifError err
            assert.isObject feed
            assert.isObject act

          "it includes the activity": (err, feed, act) ->
            assert.ifError err
            assert.isObject feed
            assert.isObject act
            assert.include feed, "items"
            assert.isArray feed.items
            assert.greater feed.items.length, 0
            assert.isObject feed.items[0]
            assert.include feed.items[0], "id"
            assert.equal feed.items[0].id, act.id

        "and the second user posts an image":
          topic: (act, cred1, cred2) ->
            url = "http://photo.localhost/api/user/photog/feed"
            callback = @callback
            post =
              verb: "post"
              object:
                objectType: "image"
                displayName: "My Photo"

            pj url, cred2, post, (err, act, resp) ->
              if err
                callback err, null
              else
                callback null, act


          "it works": (err, act) ->
            assert.ifError err
            assert.isObject act

          "and we wait a few seconds for delivery":
            topic: ->
              callback = @callback
              setTimeout (->
                callback null
              ), 5000

            "it works": (err) ->
              assert.ifError err

            "and we check the first user's inbox":
              topic: (posted, followed, cred1, cred2) ->
                callback = @callback
                url = "http://social.localhost/api/user/maven/inbox"
                gj url, cred1, (err, feed, resp) ->
                  if err
                    callback err, null, null
                  else
                    callback null, feed, posted


              "it works": (err, feed, act) ->
                assert.ifError err
                assert.isObject feed
                assert.isObject act

              "it includes the activity": (err, feed, act) ->
                assert.ifError err
                assert.isObject feed
                assert.isObject act
                assert.include feed, "items"
                assert.isArray feed.items
                assert.greater feed.items.length, 0
                assert.isObject feed.items[0]
                assert.include feed.items[0], "id"
                assert.equal feed.items[0].id, act.id

              "activity is sanitized": (err, feed, act) ->
                assert.ifError err
                assert.isObject feed
                assert.isArray feed.items
                assert.greater feed.items.length, 0
                assert.isObject feed.items[0]
                assert.isObject feed.items[0].actor
                assert.isFalse _(feed.items[0].actor).has("_user")

              "activity likes and replies feeds have right host": (err, feed, act) ->
                assert.ifError err
                assert.isObject feed
                assert.isArray feed.items
                assert.greater feed.items.length, 0
                assert.isObject feed.items[0]
                assert.isObject feed.items[0].object
                assert.isObject feed.items[0].object.likes
                assert.isString feed.items[0].object.likes.url
                assert.equal serverOf(feed.items[0].object.likes.url), "photo.localhost"
                assert.isObject feed.items[0].object.replies
                assert.isString feed.items[0].object.replies.url
                assert.equal serverOf(feed.items[0].object.replies.url), "photo.localhost"

            "and the first user responds":
              topic: (posted, followed, cred1, cred2) ->
                callback = @callback
                url = "http://social.localhost/api/user/maven/feed"
                postComment =
                  verb: "post"
                  object:
                    objectType: "comment"
                    inReplyTo: posted.object
                    content: "Nice one!"

                pj url, cred1, postComment, (err, pc, resp) ->
                  if err
                    callback err, null
                  else
                    callback null, pc


              "it works": (err, pc) ->
                assert.ifError err
                assert.isObject pc

              "and we wait a few seconds for delivery":
                topic: ->
                  callback = @callback
                  setTimeout (->
                    callback null
                  ), 5000

                "it works": (err) ->
                  assert.ifError err

                "and we check the second user's inbox":
                  topic: (pc, pi, fu, cred1, cred2) ->
                    url = "http://photo.localhost/api/user/photog/inbox"
                    callback = @callback
                    gj url, cred2, (err, feed, resp) ->
                      if err
                        callback err, null, null
                      else
                        callback null, feed, pc


                  "it works": (err, feed, act) ->
                    assert.ifError err
                    assert.isObject feed
                    assert.isObject act

                  "it includes the activity": (err, feed, act) ->
                    assert.ifError err
                    assert.isObject feed
                    assert.isObject act
                    assert.include feed, "items"
                    assert.isArray feed.items
                    assert.greater feed.items.length, 0
                    assert.isObject feed.items[0]
                    assert.include feed.items[0], "id"
                    assert.equal feed.items[0].id, act.id

                "and we check the image's replies":
                  topic: (pc, pi, fu, cred1, cred2) ->
                    url = pi.object.replies.url
                    callback = @callback
                    gj url, cred2, (err, feed, resp) ->
                      if err
                        callback err, null, null
                      else
                        callback null, feed, pc


                  "it works": (err, feed, pc) ->
                    assert.ifError err
                    assert.isObject feed

                  "feed includes the comment": (err, feed, pc) ->
                    assert.ifError err
                    assert.isObject feed
                    assert.isObject pc
                    assert.include feed, "items"
                    assert.isArray feed.items
                    assert.greater feed.items.length, 0
                    assert.isObject feed.items[0]
                    assert.include feed.items[0], "id"
                    assert.equal feed.items[0].id, pc.object.id

                "and the second user likes the comment":
                  topic: (pc, pi, fu, cred1, cred2) ->
                    url = "http://photo.localhost/api/user/photog/feed"
                    callback = @callback
                    post =
                      verb: "favorite"
                      object: pc.object

                    pj url, cred2, post, (err, act, resp) ->
                      if err
                        callback err, null
                      else
                        callback null, act


                  "it works": (err, act) ->
                    assert.ifError err
                    assert.isObject act

                  "and we wait a few seconds for delivery":
                    topic: ->
                      callback = @callback
                      setTimeout (->
                        callback null
                      ), 5000

                    "it works": (err) ->
                      assert.ifError err

                    "and we check the first user's inbox":
                      topic: (fc, pc, pi, fu, cred1, cred2) ->
                        callback = @callback
                        url = "http://social.localhost/api/user/maven/inbox"
                        gj url, cred1, (err, feed, resp) ->
                          if err
                            callback err, null, null
                          else
                            callback null, feed, fc


                      "it works": (err, feed, act) ->
                        assert.ifError err
                        assert.isObject feed
                        assert.isObject act

                      "it includes the activity": (err, feed, act) ->
                        assert.ifError err
                        assert.isObject feed
                        assert.isObject act
                        assert.include feed, "items"
                        assert.isArray feed.items
                        assert.greater feed.items.length, 0
                        assert.isObject feed.items[0]
                        assert.include feed.items[0], "id"
                        assert.equal feed.items[0].id, act.id

                    "and we check the comment's likes feed":
                      topic: (fc, pc, pi, fu, cred1, cred2) ->
                        url = pc.object.likes.url
                        callback = @callback
                        gj url, cred1, (err, feed, resp) ->
                          if err
                            callback err, null, null
                          else
                            callback null, feed, fc


                      "it works": (err, feed, fc) ->
                        assert.ifError err
                        assert.isObject feed

                      "feed includes the second user": (err, feed, fc) ->
                        assert.ifError err
                        assert.isObject feed
                        assert.isObject fc
                        assert.include feed, "items"
                        assert.isArray feed.items
                        assert.greater feed.items.length, 0
                        assert.isObject feed.items[0]
                        assert.include feed.items[0], "id"
                        assert.equal feed.items[0].id, fc.actor.id

suite["export"] module
