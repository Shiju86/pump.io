# user-test.js
#
# Test the user module
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
_ = require("underscore")
Step = require("step")
Activity = require("../lib/model/activity").Activity
modelBatch = require("./lib/model").modelBatch
Databank = databank.Databank
DatabankObject = databank.DatabankObject
suite = vows.describe("user module interface")
testSchema =
  pkey: "nickname"
  fields: ["_passwordHash", "published", "updated", "profile"]
  indices: ["profile.id"]

testData =
  create:
    nickname: "evan"
    password: "Quie3ien"
    profile:
      displayName: "Evan Prodromou"

  update:
    nickname: "evan"
    password: "correct horse battery staple" # the most secure password! see http://xkcd.com/936/


# XXX: hack hack hack
# modelBatch hard-codes ActivityObject-style
mb = modelBatch("user", "User", testSchema, testData)
mb["When we require the user module"]["and we get its User class export"]["and we create an user instance"]["auto-generated fields are there"] = (err, created) ->
  assert.isString created._passwordHash
  assert.isString created.published
  assert.isString created.updated

suite.addBatch mb
suite.addBatch "When we get the User class":
  topic: ->
    require("../lib/model/user").User

  "it exists": (User) ->
    assert.isFunction User

  "it has a fromPerson() method": (User) ->
    assert.isFunction User.fromPerson

  "it has a checkCredentials() method": (User) ->
    assert.isFunction User.checkCredentials

  "and we check the credentials for a non-existent user":
    topic: (User) ->
      cb = @callback
      User.checkCredentials "nosuchuser", "passw0rd", @callback

    "it returns null": (err, found) ->
      assert.ifError err
      assert.isNull found

  "and we create a user":
    topic: (User) ->
      props =
        nickname: "tom"
        password: "Xae3aiju"

      User.create props, @callback

    teardown: (user) ->
      if user and user.del
        user.del (err) ->


    "it works": (user) ->
      assert.isObject user

    "it has the sanitize() method": (user) ->
      assert.isFunction user.sanitize

    "it has the getProfile() method": (user) ->
      assert.isFunction user.getProfile

    "it has the getOutboxStream() method": (user) ->
      assert.isFunction user.getOutboxStream

    "it has the getInboxStream() method": (user) ->
      assert.isFunction user.getInboxStream

    "it has the getMajorOutboxStream() method": (user) ->
      assert.isFunction user.getMajorOutboxStream

    "it has the getMajorInboxStream() method": (user) ->
      assert.isFunction user.getMajorInboxStream

    "it has the getMinorOutboxStream() method": (user) ->
      assert.isFunction user.getMinorOutboxStream

    "it has the getMinorInboxStream() method": (user) ->
      assert.isFunction user.getMinorInboxStream

    "it has the getDirectInboxStream() method": (user) ->
      assert.isFunction user.getDirectInboxStream

    "it has the getMinorDirectInboxStream() method": (user) ->
      assert.isFunction user.getMinorDirectInboxStream

    "it has the getMajorDirectInboxStream() method": (user) ->
      assert.isFunction user.getMajorDirectInboxStream

    "it has the getDirectMinorInboxStream() method": (user) ->
      assert.isFunction user.getDirectMinorInboxStream

    "it has the getDirectMajorInboxStream() method": (user) ->
      assert.isFunction user.getDirectMajorInboxStream

    "it has the getLists() method": (user) ->
      assert.isFunction user.getLists

    "it has the expand() method": (user) ->
      assert.isFunction user.expand

    "it has the addToOutbox() method": (user) ->
      assert.isFunction user.addToOutbox

    "it has the addToInbox() method": (user) ->
      assert.isFunction user.addToInbox

    "it has the getFollowers() method": (user) ->
      assert.isFunction user.getFollowers

    "it has the getFollowing() method": (user) ->
      assert.isFunction user.getFollowing

    "it has the followerCount() method": (user) ->
      assert.isFunction user.followerCount

    "it has the followingCount() method": (user) ->
      assert.isFunction user.followingCount

    "it has the follow() method": (user) ->
      assert.isFunction user.follow

    "it has the stopFollowing() method": (user) ->
      assert.isFunction user.stopFollowing

    "it has the addFollower() method": (user) ->
      assert.isFunction user.addFollower

    "it has the addFollowing() method": (user) ->
      assert.isFunction user.addFollowing

    "it has the removeFollower() method": (user) ->
      assert.isFunction user.removeFollower

    "it has the removeFollowing() method": (user) ->
      assert.isFunction user.removeFollowing

    "it has the addToFavorites() method": (user) ->
      assert.isFunction user.addToFavorites

    "it has the removeFromFavorites() method": (user) ->
      assert.isFunction user.removeFromFavorites

    "it has the favoritesStream() method": (user) ->
      assert.isFunction user.favoritesStream

    "it has the uploadsStream() method": (user) ->
      assert.isFunction user.uploadsStream

    "it has a profile attribute": (user) ->
      assert.isObject user.profile
      assert.instanceOf user.profile, require("../lib/model/person").Person

    "and we check the credentials with the right password":
      topic: (user, User) ->
        User.checkCredentials "tom", "Xae3aiju", @callback

      "it works": (err, user) ->
        assert.ifError err
        assert.isObject user

    "and we check the credentials with the wrong password":
      topic: (user, User) ->
        cb = @callback
        User.checkCredentials "tom", "654321", @callback

      "it returns null": (err, found) ->
        assert.ifError err
        assert.isNull found

    "and we try to retrieve it from the person id":
      topic: (user, User) ->
        User.fromPerson user.profile.id, @callback

      "it works": (err, found) ->
        assert.ifError err
        assert.isObject found
        assert.equal found.nickname, "tom"

    "and we try to get its profile":
      topic: (user) ->
        user.getProfile @callback

      "it works": (err, profile) ->
        assert.ifError err
        assert.isObject profile
        assert.instanceOf profile, require("../lib/model/person").Person

  "and we create a user and sanitize it":
    topic: (User) ->
      cb = @callback
      props =
        nickname: "dick"
        password: "Aaf7Ieki"

      User.create props, (err, user) ->
        if err
          cb err, null
        else
          user.sanitize()
          cb null, user


    teardown: (user) ->
      if user
        user.del (err) ->


    "it works": (err, user) ->
      assert.ifError err
      assert.isObject user

    "it is sanitized": (err, user) ->
      assert.isFalse _(user).has("password")
      assert.isFalse _(user).has("_passwordHash")

  "and we create a new user and get its stream":
    topic: (User) ->
      cb = @callback
      user = null
      props =
        nickname: "harry"
        password: "Ai9AhSha"

      Step (->
        User.create props, this
      ), ((err, results) ->
        throw err  if err
        user = results
        user.getOutboxStream this
      ), ((err, outbox) ->
        throw err  if err
        outbox.getIDs 0, 20, this
      ), ((err, ids) ->
        throw err  if err
        Activity.readArray ids, this
      ), (err, activities) ->
        if err
          cb err, null
        else
          cb err,
            user: user
            activities: activities



    teardown: (results) ->
      if results
        results.user.del (err) ->


    "it works": (err, results) ->
      assert.ifError err
      assert.isObject results.user
      assert.isArray results.activities

    "it is empty": (err, results) ->
      assert.lengthOf results.activities, 0

    "and we add an activity to its stream":
      topic: (results) ->
        cb = @callback
        user = results.user
        props =
          verb: "checkin"
          object:
            objectType: "place"
            displayName: "Les Folies"
            url: "http://nominatim.openstreetmap.org/details.php?place_id=5001033"
            position: "+45.5253965-73.5818537/"
            address:
              streetAddress: "701 Mont-Royal Est"
              locality: "Montreal"
              region: "Quebec"
              postalCode: "H2J 2T5"

        Activity = require("../lib/model/activity").Activity
        act = new Activity(props)
        Step (->
          act.apply user.profile, this
        ), ((err) ->
          throw err  if err
          act.save this
        ), ((err) ->
          throw err  if err
          user.addToOutbox act, this
        ), (err) ->
          if err
            cb err, null
          else
            cb null,
              user: user
              activity: act



      "it works": (err, results) ->
        assert.ifError err

      "and we get the user stream":
        topic: (results) ->
          cb = @callback
          user = results.user
          activity = results.activity
          Step (->
            user.getOutboxStream this
          ), ((err, outbox) ->
            throw err  if err
            outbox.getIDs 0, 20, this
          ), ((err, ids) ->
            throw err  if err
            Activity.readArray ids, this
          ), (err, activities) ->
            if err
              cb err, null
            else
              cb null,
                user: user
                activity: activity
                activities: activities



        "it works": (err, results) ->
          assert.ifError err
          assert.isArray results.activities

        "it includes the added activity": (err, results) ->
          assert.lengthOf results.activities, 1
          assert.equal results.activities[0].id, results.activity.id

  "and we create a new user and get its lists stream":
    topic: (User) ->
      props =
        nickname: "gary"
        password: "eiFoT2Va"

      Step (->
        User.create props, this
      ), ((err, user) ->
        throw err  if err
        user.getLists "person", this
      ), @callback

    "it works": (err, stream) ->
      assert.ifError err
      assert.isObject stream

    "and we get the count of lists":
      topic: (stream) ->
        stream.count @callback

      "it is zero": (err, count) ->
        assert.ifError err
        assert.equal count, 0

    "and we get the first few lists":
      topic: (stream) ->
        stream.getItems 0, 20, @callback

      "it is an empty list": (err, ids) ->
        assert.ifError err
        assert.isArray ids
        assert.lengthOf ids, 0

  "and we create a new user and get its galleries stream":
    topic: (User) ->
      props =
        nickname: "chumwick"
        password: "eiFoT2Va"

      Step (->
        User.create props, this
      ), ((err, user) ->
        throw err  if err
        user.getLists "image", this
      ), @callback

    "it works": (err, stream) ->
      assert.ifError err
      assert.isObject stream

    "and we get the count of lists":
      topic: (stream) ->
        stream.count @callback

      "it is five": (err, count) ->
        assert.ifError err
        assert.equal count, 1

    "and we get the first few lists":
      topic: (stream) ->
        stream.getItems 0, 20, @callback

      "it is a single-element list": (err, ids) ->
        assert.ifError err
        assert.isArray ids
        assert.lengthOf ids, 1

  "and we create a new user and get its inbox":
    topic: (User) ->
      cb = @callback
      user = null
      props =
        nickname: "maurice"
        password: "cappadoccia1"

      Step (->
        User.create props, this
      ), ((err, results) ->
        throw err  if err
        user = results
        user.getInboxStream this
      ), ((err, inbox) ->
        throw err  if err
        inbox.getIDs 0, 20, this
      ), ((err, ids) ->
        throw err  if err
        Activity.readArray ids, this
      ), (err, activities) ->
        if err
          cb err, null
        else
          cb err,
            user: user
            activities: activities



    teardown: (results) ->
      if results
        results.user.del (err) ->


    "it works": (err, results) ->
      assert.ifError err
      assert.isObject results.user
      assert.isArray results.activities

    "it is empty": (err, results) ->
      assert.lengthOf results.activities, 0

    "and we add an activity to its inbox":
      topic: (results) ->
        cb = @callback
        user = results.user
        props =
          actor:
            id: "urn:uuid:8f7be1de-3f48-4a54-bf3f-b4fc18f3ae77"
            objectType: "person"
            displayName: "Abraham Lincoln"

          verb: "post"
          object:
            objectType: "note"
            content: "Remember to get eggs, bread, and milk."

        Activity = require("../lib/model/activity").Activity
        act = new Activity(props)
        Step (->
          act.apply user.profile, this
        ), ((err) ->
          throw err  if err
          act.save this
        ), ((err) ->
          throw err  if err
          user.addToInbox act, this
        ), (err) ->
          if err
            cb err, null
          else
            cb null,
              user: user
              activity: act



      "it works": (err, results) ->
        assert.ifError err

      "and we get the user inbox":
        topic: (results) ->
          cb = @callback
          user = results.user
          activity = results.activity
          Step (->
            user.getInboxStream this
          ), ((err, inbox) ->
            throw err  if err
            inbox.getIDs 0, 20, this
          ), ((err, ids) ->
            throw err  if err
            Activity.readArray ids, this
          ), (err, activities) ->
            if err
              cb err, null
            else
              cb null,
                user: user
                activity: activity
                activities: activities



        "it works": (err, results) ->
          assert.ifError err
          assert.isArray results.activities

        "it includes the added activity": (err, results) ->
          assert.lengthOf results.activities, 1
          assert.equal results.activities[0].id, results.activity.id

  "and we create a pair of users":
    topic: (User) ->
      cb = @callback
      Step (->
        User.create
          nickname: "shields"
          password: "1walk1nTheWind"
        , @parallel()
        User.create
          nickname: "yarnell"
          password: "1Mpull1ngArope"
        , @parallel()
      ), (err, shields, yarnell) ->
        if err
          cb err, null
        else
          cb null,
            shields: shields
            yarnell: yarnell



    "it works": (err, users) ->
      assert.ifError err

    "and we make one follow the other":
      topic: (users) ->
        users.shields.follow users.yarnell, @callback

      "it works": (err) ->
        assert.ifError err

      "and we check the first user's following list":
        topic: (users) ->
          cb = @callback
          users.shields.getFollowing 0, 20, (err, following) ->
            cb err, following, users.yarnell


        "it works": (err, following, other) ->
          assert.ifError err
          assert.isArray following

        "it is the right size": (err, following, other) ->
          assert.ifError err
          assert.lengthOf following, 1

        "it has the right data": (err, following, other) ->
          assert.ifError err
          assert.equal following[0].id, other.profile.id

      "and we check the first user's following count":
        topic: (users) ->
          users.shields.followingCount @callback

        "it works": (err, fc) ->
          assert.ifError err

        "it is correct": (err, fc) ->
          assert.ifError err
          assert.equal fc, 1

      "and we check the second user's followers list":
        topic: (users) ->
          cb = @callback
          users.yarnell.getFollowers 0, 20, (err, following) ->
            cb err, following, users.shields


        "it works": (err, followers, other) ->
          assert.ifError err
          assert.isArray followers

        "it is the right size": (err, followers, other) ->
          assert.ifError err
          assert.lengthOf followers, 1

        "it has the right data": (err, followers, other) ->
          assert.ifError err
          assert.equal followers[0].id, other.profile.id

      "and we check the second user's followers count":
        topic: (users) ->
          users.yarnell.followerCount @callback

        "it works": (err, fc) ->
          assert.ifError err

        "it is correct": (err, fc) ->
          assert.ifError err
          assert.equal fc, 1

  "and we create another pair of users following":
    topic: (User) ->
      cb = @callback
      users = {}
      Step (->
        User.create
          nickname: "captain"
          password: "b34chboyW/AHat"
        , @parallel()
        User.create
          nickname: "tenille"
          password: "Muskr4t|Sus13"
        , @parallel()
      ), ((err, captain, tenille) ->
        throw err  if err
        users.captain = captain
        users.tenille = tenille
        captain.follow tenille, this
      ), ((err) ->
        throw err  if err
        users.captain.stopFollowing users.tenille, this
      ), (err) ->
        if err
          cb err, null
        else
          cb null, users


    "it works": (err, users) ->
      assert.ifError err

    "and we check the first user's following list":
      topic: (users) ->
        cb = @callback
        users.captain.getFollowing 0, 20, @callback

      "it works": (err, following, other) ->
        assert.ifError err
        assert.isArray following

      "it is the right size": (err, following, other) ->
        assert.ifError err
        assert.lengthOf following, 0

    "and we check the first user's following count":
      topic: (users) ->
        users.captain.followingCount @callback

      "it works": (err, fc) ->
        assert.ifError err

      "it is correct": (err, fc) ->
        assert.ifError err
        assert.equal fc, 0

    "and we check the second user's followers list":
      topic: (users) ->
        users.tenille.getFollowers 0, 20, @callback

      "it works": (err, followers, other) ->
        assert.ifError err
        assert.isArray followers

      "it is the right size": (err, followers, other) ->
        assert.ifError err
        assert.lengthOf followers, 0

    "and we check the second user's followers count":
      topic: (users) ->
        users.tenille.followerCount @callback

      "it works": (err, fc) ->
        assert.ifError err

      "it is correct": (err, fc) ->
        assert.ifError err
        assert.equal fc, 0

  "and one user follows another twice":
    topic: (User) ->
      cb = @callback
      users = {}
      Step (->
        User.create
          nickname: "boris"
          password: "squirrel"
        , @parallel()
        User.create
          nickname: "natasha"
          password: "moose"
        , @parallel()
      ), ((err, boris, natasha) ->
        throw err  if err
        users.boris = boris
        users.natasha = natasha
        users.boris.follow users.natasha, this
      ), ((err) ->
        throw err  if err
        users.boris.follow users.natasha, this
      ), (err) ->
        if err
          cb null
        else
          cb new Error("Unexpected success")


    "it fails correctly": (err) ->
      assert.ifError err

  "and one user stops following a user they never followed":
    topic: (User) ->
      cb = @callback
      users = {}
      Step (->
        User.create
          nickname: "rocky"
          password: "flying"
        , @parallel()
        User.create
          nickname: "bullwinkle"
          password: "rabbit"
        , @parallel()
      ), ((err, rocky, bullwinkle) ->
        throw err  if err
        users.rocky = rocky
        users.bullwinkle = bullwinkle
        users.rocky.stopFollowing users.bullwinkle, this
      ), (err) ->
        if err
          cb null
        else
          cb new Error("Unexpected success")


    "it fails correctly": (err) ->
      assert.ifError err

  "and we create a bunch of users":
    topic: (User) ->
      cb = @callback
      MAX_USERS = 50
      Step (->
        i = undefined
        group = @group()
        i = 0
        while i < MAX_USERS
          User.create
            nickname: "clown" + i
            password: "Ha6quo6I" + i
          , group()
          i++
      ), (err, users) ->
        if err
          cb err, null
        else
          cb null, users


    "it works": (err, users) ->
      assert.ifError err
      assert.isArray users
      assert.lengthOf users, 50

    "and they all follow someone":
      topic: (users) ->
        cb = @callback
        MAX_USERS = 50
        Step (->
          i = undefined
          group = @group()
          i = 1
          while i < users.length
            users[i].follow users[0], group()
            i++
        ), (err) ->
          cb err


      "it works": (err) ->
        assert.ifError err

      "and we check the followed user's followers list":
        topic: (users) ->
          users[0].getFollowers 0, users.length + 1, @callback

        "it works": (err, followers) ->
          assert.ifError err
          assert.isArray followers
          assert.lengthOf followers, 49

      "and we check the followed user's followers count":
        topic: (users) ->
          users[0].followerCount @callback

        "it works": (err, fc) ->
          assert.ifError err

        "it is correct": (err, fc) ->
          assert.ifError err
          assert.equal fc, 49

      "and we check the following users' following lists":
        topic: (users) ->
          cb = @callback
          MAX_USERS = 50
          Step (->
            i = undefined
            group = @group()
            i = 1
            while i < users.length
              users[i].getFollowing 0, 20, group()
              i++
          ), cb

        "it works": (err, lists) ->
          i = undefined
          assert.ifError err
          assert.isArray lists
          assert.lengthOf lists, 49
          i = 0
          while i < lists.length
            assert.isArray lists[i]
            assert.lengthOf lists[i], 1
            i++

      "and we check the following users' following counts":
        topic: (users) ->
          cb = @callback
          MAX_USERS = 50
          Step (->
            i = undefined
            group = @group()
            i = 1
            while i < users.length
              users[i].followingCount group()
              i++
          ), cb

        "it works": (err, counts) ->
          i = undefined
          assert.ifError err
          assert.isArray counts
          assert.lengthOf counts, 49
          i = 0
          while i < counts.length
            assert.equal counts[i], 1
            i++

emptyStreamContext = (streamgetter) ->
  topic: (user) ->
    callback = @callback
    Step (->
      streamgetter user, this
    ), ((err, str) ->
      throw err  if err
      str.getIDs 0, 20, this
    ), callback

  "it's empty": (err, activities) ->
    assert.ifError err
    assert.isEmpty activities

streamCountContext = (streamgetter, targetCount) ->
  ctx = topic: (act, user) ->
    callback = @callback
    Step (->
      streamgetter user, this
    ), ((err, str) ->
      throw err  if err
      str.getIDs 0, 20, this
    ), (err, activities) ->
      callback err, act, activities


  label = (if (targetCount > 0) then "it's in there" else "it's not in there")
  ctx[label] = (err, act, activities) ->
    matches = undefined
    assert.ifError err
    assert.isObject act
    assert.isArray activities
    matches = activities.filter((item) ->
      item is act.id
    )
    assert.lengthOf matches, targetCount

  ctx

inStreamContext = (streamgetter) ->
  streamCountContext streamgetter, 1

notInStreamContext = (streamgetter) ->
  streamCountContext streamgetter, 0


# Tests for major, minor streams
suite.addBatch
  "When we create a new user":
    topic: ->
      User = require("../lib/model/user").User
      props =
        nickname: "archie"
        password: "B0Y|the/way|Glenn+Miller|played"

      User.create props, @callback

    "it works": (err, user) ->
      assert.ifError err

    "and we check their minor inbox": emptyStreamContext((user, callback) ->
      user.getMinorInboxStream callback
    )
    "and we check their minor outbox": emptyStreamContext((user, callback) ->
      user.getMinorOutboxStream callback
    )
    "and we check their major inbox": emptyStreamContext((user, callback) ->
      user.getMajorInboxStream callback
    )
    "and we check their major inbox": emptyStreamContext((user, callback) ->
      user.getMajorOutboxStream callback
    )

  "When we create another user":
    topic: ->
      User = require("../lib/model/user").User
      props =
        nickname: "edith"
        password: "s0ngz|that|made|Th3|h1t|P4r4de"

      User.create props, @callback

    "it works": (err, user) ->
      assert.ifError err

    "and we add a major activity":
      topic: (user) ->
        act = undefined
        props =
          actor: user.profile
          verb: "post"
          object:
            objectType: "note"
            content: "Cling peaches"

        callback = @callback
        Step (->
          Activity.create props, this
        ), ((err, result) ->
          throw err  if err
          act = result
          user.addToInbox act, @parallel()
          user.addToOutbox act, @parallel()
        ), (err) ->
          if err
            callback err, null, null
          else
            callback null, act, user


      "it works": (err, activity, user) ->
        assert.ifError err

      "and we check their minor inbox": notInStreamContext((user, callback) ->
        user.getMinorInboxStream callback
      )
      "and we check their minor outbox": notInStreamContext((user, callback) ->
        user.getMinorOutboxStream callback
      )
      "and we check their major inbox": inStreamContext((user, callback) ->
        user.getMajorInboxStream callback
      )
      "and we check their major outbox": inStreamContext((user, callback) ->
        user.getMajorOutboxStream callback
      )

  "When we create yet another user":
    topic: ->
      User = require("../lib/model/user").User
      props =
        nickname: "gloria"
        password: "0h,d4DDY!"

      User.create props, @callback

    "it works": (err, user) ->
      assert.ifError err

    "and we add a minor activity":
      topic: (user) ->
        act = undefined
        props =
          actor: user.profile
          verb: "favorite"
          object:
            objectType: "image"
            id: "3740ed6e-fa2b-11e1-9287-70f1a154e1aa"

        callback = @callback
        Step (->
          Activity.create props, this
        ), ((err, result) ->
          throw err  if err
          act = result
          user.addToInbox act, @parallel()
          user.addToOutbox act, @parallel()
        ), (err) ->
          if err
            callback err, null, null
          else
            callback null, act, user


      "it works": (err, activity, user) ->
        assert.ifError err

      "and we check their minor inbox": inStreamContext((user, callback) ->
        user.getMinorInboxStream callback
      )
      "and we check their minor outbox": inStreamContext((user, callback) ->
        user.getMinorOutboxStream callback
      )
      "and we check their major inbox": notInStreamContext((user, callback) ->
        user.getMajorInboxStream callback
      )
      "and we check their major outbox": notInStreamContext((user, callback) ->
        user.getMajorOutboxStream callback
      )


# Test user nickname rules
goodNickname = (nickname) ->
  topic: ->
    User = require("../lib/model/user").User
    props =
      nickname: nickname
      password: "Kei1goos"

    User.create props, @callback

  "it works": (err, user) ->
    assert.ifError err
    assert.isObject user

  "the nickname is correct": (err, user) ->
    assert.ifError err
    assert.isObject user
    assert.equal nickname, user.nickname

badNickname = (nickname) ->
  topic: ->
    User = require("../lib/model/user").User
    props =
      nickname: nickname
      password: "AQuah5co"

    callback = @callback
    User.create props, (err, user) ->
      if err and err instanceof User.BadNicknameError
        callback null
      else
        callback new Error("Unexpected success")


  "it fails correctly": (err) ->
    assert.ifError err

suite.addBatch
  "When we create a new user with a long nickname less than 64 chars": goodNickname("james_james_morrison_morrison_weatherby_george_dupree")
  "When we create a user with a nickname with a -": goodNickname("captain-caveman")
  "When we create a user with a nickname with a _": goodNickname("captain_caveman")
  "When we create a user with a nickname with a .": goodNickname("captain.caveman")
  "When we create a user with a nickname with capital letters": goodNickname("CaptainCaveman")
  "When we create a user with a nickname with one char": goodNickname("c")
  "When we create a new user with a nickname longer than 64 chars": badNickname("adolphblainecharlesdavidearlfrederickgeraldhubertirvimjohn" + "kennethloydmartinnerooliverpaulquincyrandolphshermanthomasuncas" + "victorwillianxerxesyancyzeus")
  "When we create a new user with a nickname with a forbidden character": badNickname("arnold/palmer")
  "When we create a new user with a nickname with a blank": badNickname("Captain Caveman")
  "When we create a new user with an empty nickname": badNickname("")
  "When we create a new user with nickname 'api'": badNickname("api")
  "When we create a new user with nickname 'oauth'": badNickname("oauth")

activityMakerContext = (maker, rest) ->
  ctx =
    topic: (toUser, fromUser) ->
      Activity = require("../lib/model/activity").Activity
      callback = @callback
      theAct = undefined
      Step (->
        act = maker(toUser, fromUser)
        Activity.create act, this
      ), ((err, act) ->
        throw err  if err
        theAct = act
        toUser.addToInbox act, this
      ), (err) ->
        callback err, theAct


    "it works": (err, act) ->
      assert.ifError err
      assert.isObject act

  _.extend ctx, rest
  ctx


# Tests for direct, direct-major, and direct-minor streams
suite.addBatch "When we get the User class":
  topic: ->
    require("../lib/model/user").User

  "it works": (User) ->
    assert.isFunction User

  "and we create a new user":
    topic: (User) ->
      props =
        nickname: "george"
        password: "moving-on-up"

      User.create props, @callback

    "it works": (err, user) ->
      assert.ifError err

    "and we check their direct inbox": emptyStreamContext((user, callback) ->
      user.getDirectInboxStream callback
    )
    "and we check their direct minor inbox": emptyStreamContext((user, callback) ->
      user.getMinorDirectInboxStream callback
    )
    "and we check their direct major inbox": emptyStreamContext((user, callback) ->
      user.getMajorDirectInboxStream callback
    )

  "and we create a pair of users":
    topic: (User) ->
      props1 =
        nickname: "louise"
        password: "moving-on-up2"

      props2 =
        nickname: "florence"
        password: "maid/up1"

      Step (->
        User.create props2, @parallel()
        User.create props1, @parallel()
      ), @callback

    "it works": (err, toUser, fromUser) ->
      assert.ifError err
      assert.isObject fromUser
      assert.isObject toUser

    "and one user sends a major activity to the other": activityMakerContext((toUser, fromUser) ->
      actor: fromUser.profile
      to: [toUser.profile]
      verb: "post"
      object:
        objectType: "note"
        content: "Please get the door"
    ,
      "and we check the recipient's direct inbox": inStreamContext((user, callback) ->
        user.getDirectInboxStream callback
      )
      "and we check the recipient's direct minor inbox": notInStreamContext((user, callback) ->
        user.getDirectMinorInboxStream callback
      )
      "and we check the recipient's direct major inbox": inStreamContext((user, callback) ->
        user.getDirectMajorInboxStream callback
      )
    )
    "and one user sends a minor activity to the other": activityMakerContext((toUser, fromUser) ->
      actor: fromUser.profile
      to: [toUser.profile]
      verb: "favorite"
      object:
        id: "urn:uuid:c6591278-0418-11e2-ade3-70f1a154e1aa"
        objectType: "audio"
    ,
      "and we check the recipient's direct inbox": inStreamContext((user, callback) ->
        user.getDirectInboxStream callback
      )
      "and we check the recipient's direct minor inbox": inStreamContext((user, callback) ->
        user.getDirectMinorInboxStream callback
      )
      "and we check the recipient's direct major inbox": notInStreamContext((user, callback) ->
        user.getDirectMajorInboxStream callback
      )
    )
    "and one user sends a major activity bto the other": activityMakerContext((toUser, fromUser) ->
      actor: fromUser.profile
      bto: [toUser.profile]
      verb: "post"
      object:
        objectType: "note"
        content: "Please wash George's underwear."
    ,
      "and we check the recipient's direct inbox": inStreamContext((user, callback) ->
        user.getDirectInboxStream callback
      )
      "and we check the recipient's direct minor inbox": notInStreamContext((user, callback) ->
        user.getDirectMinorInboxStream callback
      )
      "and we check the recipient's direct major inbox": inStreamContext((user, callback) ->
        user.getDirectMajorInboxStream callback
      )
    )
    "and one user sends a minor activity bto the other": activityMakerContext((toUser, fromUser) ->
      actor: fromUser.profile
      bto: [toUser.profile]
      verb: "favorite"
      object:
        id: "urn:uuid:5982b964-0414-11e2-8ced-70f1a154e1aa"
        objectType: "service"
    ,
      "and we check the recipient's direct inbox": inStreamContext((user, callback) ->
        user.getDirectInboxStream callback
      )
      "and we check the recipient's direct minor inbox": inStreamContext((user, callback) ->
        user.getDirectMinorInboxStream callback
      )
      "and we check the recipient's direct major inbox": notInStreamContext((user, callback) ->
        user.getDirectMajorInboxStream callback
      )
    )
    "and one user sends a minor activity to the public": activityMakerContext((toUser, fromUser) ->
      actor: fromUser.profile
      to: [
        id: "http://activityschema.org/collection/public"
        objectType: "collection"
      ]
      verb: "favorite"
      object:
        id: "urn:uuid:0e6b0f90-0413-11e2-84fb-70f1a154e1aa"
        objectType: "video"
    ,
      "and we check the other user's direct inbox": notInStreamContext((user, callback) ->
        user.getDirectInboxStream callback
      )
      "and we check the other user's direct minor inbox": notInStreamContext((user, callback) ->
        user.getDirectMinorInboxStream callback
      )
      "and we check the other user's direct major inbox": notInStreamContext((user, callback) ->
        user.getDirectMajorInboxStream callback
      )
    )
    "and one user sends a major activity and cc's the other": activityMakerContext((toUser, fromUser) ->
      actor: fromUser.profile
      cc: [toUser.profile]
      verb: "post"
      object:
        id: "I'm tired."
        objectType: "note"
    ,
      "and we check the other user's direct inbox": notInStreamContext((user, callback) ->
        user.getDirectInboxStream callback
      )
      "and we check the other user's direct minor inbox": notInStreamContext((user, callback) ->
        user.getDirectMinorInboxStream callback
      )
      "and we check the other user's direct major inbox": notInStreamContext((user, callback) ->
        user.getDirectMajorInboxStream callback
      )
    )
    "and one user sends a major activity and bcc's the other": activityMakerContext((toUser, fromUser) ->
      actor: fromUser.profile
      bcc: [toUser.profile]
      verb: "post"
      object:
        id: "It's hot."
        objectType: "note"
    ,
      "and we check the other user's direct inbox": notInStreamContext((user, callback) ->
        user.getDirectInboxStream callback
      )
      "and we check the other user's direct minor inbox": notInStreamContext((user, callback) ->
        user.getDirectMinorInboxStream callback
      )
      "and we check the other user's direct major inbox": notInStreamContext((user, callback) ->
        user.getDirectMajorInboxStream callback
      )
    )

suite.addBatch "When we get the User class":
  topic: ->
    require("../lib/model/user").User

  "it works": (User) ->
    assert.isFunction User

  "and we create a new user":
    topic: (User) ->
      props =
        nickname: "whatever"
        password: "no-energy"

      User.create props, @callback

    "it works": (err, user) ->
      assert.ifError err

    "and we check their direct inbox": emptyStreamContext((user, callback) ->
      user.uploadsStream callback
    )

suite["export"] module
