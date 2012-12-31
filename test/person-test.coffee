# person-test.js
#
# Test the person module
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
databank = require("databank")
fs = require("fs")
path = require("path")
Step = require("step")
_ = require("underscore")
schema = require("../lib/schema").schema
URLMaker = require("../lib/urlmaker").URLMaker
modelBatch = require("./lib/model").modelBatch
Databank = databank.Databank
DatabankObject = databank.DatabankObject
suite = vows.describe("person module interface")
tc = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json")))
testSchema =
  pkey: "id"
  fields: ["displayName", "image", "published", "updated", "url", "_uuid"]
  indices: ["_uuid"]

testData =
  create:
    displayName: "George Washington"
    image:
      url: "http://www.georgewashington.si.edu/portrait/images/face.jpg"
      width: 83
      height: 120

  update:
    displayName: "President George Washington"

suite.addBatch modelBatch("person", "Person", testSchema, testData)
suite.addBatch "When we get the Person class":
  topic: ->
    cb = @callback
    
    # Need this to make IDs
    URLMaker.hostname = "example.net"
    URLMaker.port = 4815
    
    # Dummy databank
    tc.params.schema = schema
    db = Databank.get(tc.driver, tc.params)
    db.connect {}, (err) ->
      mod = undefined
      if err
        cb err, null
        return
      DatabankObject.bank = db
      mod = require("../lib/model/person")
      unless mod
        cb new Error("No module"), null
        return
      cb null, mod.Person


  "it works": (err, Person) ->
    assert.ifError err
    assert.isFunction Person

  "and we instantiate a non-user Person":
    topic: (Person) ->
      Person.create
        displayName: "Gerald"
      , @callback

    "it works": (err, person) ->
      assert.ifError err
      assert.isObject person
      assert.instanceOf person, require("../lib/model/person").Person

    "it has a followersURL() method": (err, person) ->
      assert.ifError err
      assert.isObject person
      assert.isFunction person.followersURL

    "it has a getInbox() method": (err, person) ->
      assert.ifError err
      assert.isObject person
      assert.isFunction person.getInbox

    "and we get its followersURL":
      topic: (person) ->
        person.followersURL @callback

      "it works": (err, url) ->
        assert.ifError err

      "it is null": (err, url) ->
        assert.ifError err
        assert.isNull url

  "and we create a user":
    topic: (Person) ->
      User = require("../lib/model/user").User
      User.create
        nickname: "evan"
        password: "one23four56"
      , @callback

    "it works": (err, user) ->
      assert.ifError err

    "and we get the followersURL of the profile":
      topic: (user) ->
        user.profile.followersURL @callback

      "it works": (err, url) ->
        assert.ifError err
        assert.isString url

      "data is correct": (err, url) ->
        assert.ifError err
        assert.isString url
        assert.equal url, "http://example.net:4815/api/user/evan/followers"

    "and we get the inbox of the profile":
      topic: (user) ->
        user.profile.getInbox @callback

      "it works": (err, url) ->
        assert.ifError err
        assert.isString url

      "data is correct": (err, url) ->
        assert.ifError err
        assert.isString url
        assert.equal url, "http://example.net:4815/api/user/evan/inbox"

  "and we create a user and expand the profile":
    topic: (Person) ->
      User = require("../lib/model/user").User
      user = undefined
      callback = @callback
      Step (->
        User.create
          nickname: "aldus"
          password: "one23four56"
        , this
      ), ((err, result) ->
        throw err  if err
        user = result
        user.expand this
      ), (err) ->
        if err
          callback err, null
        else
          callback null, user


    "it works": (err, user) ->
      assert.ifError err

    "the profile has the right links": (err, user) ->
      assert.ifError err
      assert.isObject user
      assert.isObject user.profile
      assert.isObject user.profile.links
      assert.isObject user.profile.links.self
      assert.isObject user.profile.links["activity-inbox"]
      assert.isObject user.profile.links["activity-outbox"]

    "and we expand the profile's feeds":
      topic: (user) ->
        callback = @callback
        user.profile.expandFeeds (err) ->
          callback err, user


      "the profile has the right feeds": (err, user) ->
        assert.ifError err
        assert.isObject user
        assert.isObject user.profile
        assert.isFalse _(user.profile).has("likes")
        assert.isFalse _(user.profile).has("replies")
        assert.isObject user.profile.followers
        assert.isString user.profile.followers.url
        assert.isNumber user.profile.followers.totalItems
        assert.isObject user.profile.following
        assert.isString user.profile.following.url
        assert.isNumber user.profile.following.totalItems
        assert.isObject user.profile.lists
        assert.isString user.profile.lists.url
        assert.isNumber user.profile.lists.totalItems
        assert.isObject user.profile.favorites
        assert.isString user.profile.favorites.url
        assert.isNumber user.profile.lists.totalItems

suite["export"] module
