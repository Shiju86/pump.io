# user-virtual-collection-test.js
#
# Test the followers, following collections for a new user
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
_ = require("underscore")
Step = require("step")
Collection = require("../lib/model/collection").Collection
URLMaker = require("../lib/urlmaker").URLMaker
schema = require("../lib/schema").schema
Databank = databank.Databank
DatabankObject = databank.DatabankObject
suite = vows.describe("user virtual collection interface")
tc = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json")))
suite.addBatch "When we get the User class":
  topic: ->
    cb = @callback
    
    # Need this to make IDs
    URLMaker.hostname = "example.net"
    URLMaker.port = 80
    
    # Dummy databank
    tc.params.schema = schema
    db = Databank.get(tc.driver, tc.params)
    db.connect {}, (err) ->
      User = undefined
      DatabankObject.bank = db
      User = require("../lib/model/user").User or null
      cb null, User


  "and we create a user":
    topic: (User) ->
      props =
        nickname: "jared"
        password: "eeng7Dox"

      User.create props, @callback

    "it works": (err, user) ->
      assert.ifError err
      assert.isObject user

    teardown: (user) ->
      if user and user.del
        user.del (err) ->


    "and we get the followers collection":
      topic: (user) ->
        callback = @callback
        Step (->
          user.profile.expandFeeds this
        ), ((err) ->
          throw err  if err
          Collection.get user.profile.followers.url, callback
        ), callback

      "it works": (err, coll) ->
        assert.ifError err
        assert.isObject coll

      "it has the right members": (err, coll) ->
        assert.ifError err
        assert.isObject coll
        assert.equal coll.id, URLMaker.makeURL("/api/user/jared/followers")
        assert.equal coll.url, URLMaker.makeURL("/jared/followers")
        assert.equal coll.displayName, "Followers"
        assert.equal coll.links.self.href, URLMaker.makeURL("/api/user/jared/followers")
        assert.equal coll.members.url, URLMaker.makeURL("/api/user/jared/followers")

      "and we check if it's a list":
        topic: (coll) ->
          Collection.isList coll, @callback

        "it is not": (err, user) ->
          assert.ifError err
          assert.isFalse user

    "and we get the following collection":
      topic: (user) ->
        callback = @callback
        Step (->
          user.profile.expandFeeds this
        ), ((err) ->
          throw err  if err
          Collection.get user.profile.following.url, callback
        ), callback

      "it works": (err, coll) ->
        assert.ifError err
        assert.isObject coll

      "it has the right members": (err, coll) ->
        assert.ifError err
        assert.isObject coll
        assert.equal coll.id, URLMaker.makeURL("api/user/jared/following")
        assert.equal coll.url, URLMaker.makeURL("/jared/following")
        assert.equal coll.displayName, "Following"
        assert.equal coll.links.self.href, URLMaker.makeURL("/api/user/jared/following")
        assert.equal coll.members.url, URLMaker.makeURL("/api/user/jared/following")

      "and we check if it's a list":
        topic: (coll) ->
          Collection.isList coll, @callback

        "it is not": (err, user) ->
          assert.ifError err
          assert.isFalse user

suite["export"] module
