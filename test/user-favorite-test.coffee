# user-favorite-test.js
#
# Test the user favoriting mechanism
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
fs = require("fs")
path = require("path")
schema = require("../lib/schema").schema
URLMaker = require("../lib/urlmaker").URLMaker
Databank = databank.Databank
DatabankObject = databank.DatabankObject
a2m = (arr, prop) ->
  i = undefined
  map = {}
  key = undefined
  value = undefined
  i = 0
  while i < arr.length
    value = arr[i]
    key = value[prop]
    map[key] = value
    i++
  map

suite = vows.describe("user favorite interface")
tc = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json")))
suite.addBatch "When we get the User class":
  topic: ->
    cb = @callback
    
    # Need this to make IDs
    URLMaker.hostname = "example.net"
    
    # Dummy databank
    tc.params.schema = schema
    db = Databank.get(tc.driver, tc.params)
    db.connect {}, (err) ->
      User = undefined
      DatabankObject.bank = db
      User = require("../lib/model/user").User or null
      cb null, User


  "it exists": (User) ->
    assert.isFunction User

  "and we create a user":
    topic: (User) ->
      props =
        nickname: "bert"
        password: "p1dgeons"

      User.create props, @callback

    teardown: (user) ->
      if user and user.del
        user.del (err) ->


    "it works": (user) ->
      assert.isObject user

    "and it favorites a known object":
      topic: (user) ->
        cb = @callback
        Image = require("../lib/model/image").Image
        obj = undefined
        Step (->
          Image.create
            displayName: "Courage Wolf"
            url: "http://i0.kym-cdn.com/photos/images/newsfeed/000/159/986/Couragewolf1.jpg"
          , this
        ), ((err, image) ->
          throw err  if err
          obj = image
          user.addToFavorites image, this
        ), (err) ->
          if err
            cb err, null
          else
            cb err, obj


      "it works": (err, image) ->
        assert.ifError err

      "and it unfavorites that object":
        topic: (image, user) ->
          user.removeFromFavorites image, @callback

        "it works": (err) ->
          assert.ifError err

    "and it favorites an unknown object":
      topic: (user) ->
        cb = @callback
        user.addToFavorites
          id: "urn:uuid:5be685ef-f50b-458b-bfd3-3ca004eb0e89"
          objectType: "image"
        , @callback

      "it works": (err) ->
        assert.ifError err

      "and it unfavorites that object":
        topic: (user) ->
          user.removeFromFavorites
            id: "urn:uuid:5be685ef-f50b-458b-bfd3-3ca004eb0e89"
            objectType: "image"
          , @callback

        "it works": (err) ->
          assert.ifError err

    "and it unfavorites an object it never favorited":
      topic: (user) ->
        cb = @callback
        Audio = require("../lib/model/audio").Audio
        Step (->
          Audio.create
            displayName: "Spock"
            url: "http://musicbrainz.org/recording/c1038685-49f3-45d7-bb26-1372f1052126"
          , this
        ), ((err, audio) ->
          throw err  if err
          user.removeFromFavorites audio, this
        ), (err) ->
          if err
            cb null
          else
            cb new Error("Unexpected success")


      "it fails correctly": (err) ->
        assert.ifError err

  "and we get the stream of favorites for a new user":
    topic: (User) ->
      cb = @callback
      props =
        nickname: "shambler"
        password: "grey|skull1"

      Step (->
        User.create props, this
      ), ((err, user) ->
        throw err  if err
        user.favoritesStream this
      ), (err, stream) ->
        if err
          cb err, null
        else
          cb null, stream


    "it works": (err, stream) ->
      assert.ifError err
      assert.isObject stream

  "and we get the list of favorites for a new user":
    topic: (User) ->
      cb = @callback
      props =
        nickname: "carroway"
        password: "feld,spar"

      Step (->
        User.create props, this
      ), ((err, user) ->
        throw err  if err
        user.getFavorites 0, 20, this
      ), (err, faves) ->
        if err
          cb err, null
        else
          cb null, faves


    "it works": (err, faves) ->
      assert.ifError err

    "it looks right": (err, faves) ->
      assert.ifError err
      assert.isArray faves
      assert.lengthOf faves, 0

  "and we get the count of favorites for a new user":
    topic: (User) ->
      cb = @callback
      props =
        nickname: "cookie"
        password: "cookies!"

      Step (->
        User.create props, this
      ), ((err, user) ->
        throw err  if err
        user.favoritesCount this
      ), (err, count) ->
        if err
          cb err, null
        else
          cb null, count


    "it works": (err, count) ->
      assert.ifError err

    "it looks right": (err, count) ->
      assert.ifError err
      assert.equal count, 0

  "and a new user favors an object":
    topic: (User) ->
      cb = @callback
      user = undefined
      image = undefined
      Step (->
        User.create
          nickname: "ernie"
          password: "rubber duckie"
        , this
      ), ((err, results) ->
        Image = require("../lib/model/image").Image
        throw err  if err
        user = results
        Image.create
          displayName: "Evan's avatar"
          url: "https://c778552.ssl.cf2.rackcdn.com/evan/1-96-20120103014637.jpeg"
        , this
      ), ((err, results) ->
        throw err  if err
        image = results
        user.addToFavorites image, this
      ), (err) ->
        if err
          cb err, null, null
        else
          cb null, user, image


    "it works": (err, user, image) ->
      assert.ifError err
      assert.isObject user
      assert.isObject image

    "and we check the user favorites list":
      topic: (user, image) ->
        cb = @callback
        user.getFavorites 0, 20, (err, faves) ->
          cb err, faves, image


      "it works": (err, faves, image) ->
        assert.ifError err

      "it is the right size": (err, faves, image) ->
        assert.ifError err
        assert.lengthOf faves, 1

      "it has the right data": (err, faves, image) ->
        assert.ifError err
        assert.equal faves[0].id, image.id

    "and we check the user favorites count":
      topic: (user, image) ->
        cb = @callback
        user.favoritesCount cb

      "it works": (err, count) ->
        assert.ifError err

      "it is correct": (err, count) ->
        assert.ifError err
        assert.equal count, 1

  "and a new user favors a lot of objects":
    topic: (User) ->
      cb = @callback
      user = undefined
      images = undefined
      Step (->
        User.create
          nickname: "count"
          password: "one,two,three,four"
        , this
      ), ((err, results) ->
        Image = require("../lib/model/image").Image
        i = 0
        group = @group()
        throw err  if err
        user = results
        i = 0
        while i < 5000
          Image.create
            displayName: "Image for #" + i
            increment: i
            url: "http://" + i + ".jpg.to"
          , group()
          i++
      ), ((err, results) ->
        i = 0
        group = @group()
        throw err  if err
        images = results
        i = 0
        while i < images.length
          user.addToFavorites images[i], group()
          i++
      ), (err) ->
        if err
          cb err, null, null
        else
          cb null, user, images


    "it works": (err, user, images) ->
      assert.ifError err
      assert.isObject user
      assert.isArray images
      assert.lengthOf images, 5000
      i = 0

      while i < images.length
        assert.isObject images[i]
        i++

    "and we check the user favorites list":
      topic: (user, images) ->
        cb = @callback
        user.getFavorites 0, 5001, (err, faves) ->
          cb err, faves, images


      "it works": (err, faves, images) ->
        assert.ifError err

      "it is the right size": (err, faves, images) ->
        assert.ifError err
        assert.lengthOf faves, 5000

      "it has the right data": (err, faves, images) ->
        fm = undefined
        im = undefined
        id = undefined
        assert.ifError err
        fm = a2m(faves, "id")
        im = a2m(images, "id")
        for id of im
          assert.include fm, id
        for id of fm
          assert.include im, id

    "and we check the user favorites count":
      topic: (user, image) ->
        cb = @callback
        user.favoritesCount cb

      "it works": (err, count) ->
        assert.ifError err

      "it is correct": (err, count) ->
        assert.ifError err
        assert.equal count, 5000

suite["export"] module
