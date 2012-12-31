# lib/finishers.js
#
# Functions for adding extra flags and stream data to API output
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
_ = require("underscore")
Step = require("step")
ActivityObject = require("../lib/model/activityobject").ActivityObject
Edge = require("../lib/model/edge").Edge
Favorite = require("../lib/model/favorite").Favorite
Share = require("../lib/model/share").Share
FilteredStream = require("../lib/filteredstream").FilteredStream
filters = require("../lib/filters")
recipientsOnly = filters.recipientsOnly
objectRecipientsOnly = filters.objectRecipientsOnly
objectPublicOnly = filters.objectPublicOnly
publicOnly = filters.publicOnly

# finisher that adds followed flag to stuff
addFollowedFinisher = (req, collection, callback) ->
  
  # Ignore for non-users
  unless req.remoteUser
    callback null
    return
  addFollowed req.remoteUser.profile, _.pluck(collection.items, "object"), callback

addFollowed = (profile, objects, callback) ->
  edgeIDs = undefined
  
  # Ignore for non-users
  unless profile
    callback null
    return
  edgeIDs = objects.map((object) ->
    Edge.id profile.id, object.id
  )
  Step (->
    Edge.readAll edgeIDs, this
  ), (err, edges) ->
    if err
      callback err
    else
      _.each objects, (object, i) ->
        edgeID = edgeIDs[i]
        object.pump_io = {}  unless _.has(object, "pump_io")
        if _.has(edges, edgeID) and _.isObject(edges[edgeID])
          object.pump_io.followed = true
        else
          object.pump_io.followed = false

      callback null



# finisher that adds shared flag to stuff
addSharedFinisher = (req, collection, callback) ->
  
  # Ignore for non-users
  unless req.remoteUser
    callback null
    return
  addShared req.remoteUser.profile, _.pluck(collection.items, "object"), callback

addShared = (profile, objects, callback) ->
  shareIDs = undefined
  
  # Ignore for non-users
  unless profile
    callback null
    return
  shareIDs = objects.map((object) ->
    Share.id profile, object
  )
  Step (->
    Share.readAll shareIDs, this
  ), (err, shares) ->
    if err
      callback err
    else
      _.each objects, (object, i) ->
        shareID = shareIDs[i]
        object.pump_io = {}  unless _.has(object, "pump_io")
        if _.has(shares, shareID) and _.isObject(shares[shareID])
          object.pump_io.shared = true
        else
          object.pump_io.shared = false

      callback null



# finisher that adds liked flag to stuff
addLikedFinisher = (req, collection, callback) ->
  
  # Ignore for non-users
  unless req.remoteUser
    callback null
    return
  addLiked req.remoteUser.profile, _.pluck(collection.items, "object"), callback

addLiked = (profile, objects, callback) ->
  faveIDs = undefined
  
  # Ignore for non-users
  unless profile
    callback null
    return
  faveIDs = objects.map((object) ->
    Favorite.id profile.id, object.id
  )
  Step (->
    Favorite.readAll faveIDs, this
  ), (err, faves) ->
    if err
      callback err
    else
      _.each objects, (object, i) ->
        faveID = faveIDs[i]
        if _.has(faves, faveID) and _.isObject(faves[faveID])
          object.liked = true
        else
          object.liked = false

      callback null


firstFewRepliesFinisher = (req, collection, callback) ->
  profile = (if (req.remoteUser) then req.remoteUser.profile else null)
  objects = _.pluck(collection.items, "object")
  firstFewReplies profile, objects, callback

firstFewReplies = (profile, objs, callback) ->
  getReplies = (obj, callback) ->
    if not _.has(obj, "replies") or not _.isObject(obj.replies) or (_.has(obj.replies, "totalItems") and obj.replies.totalItems is 0)
      callback null
      return
    Step (->
      obj.getRepliesStream this
    ), ((err, str) ->
      filtered = undefined
      throw err  if err
      unless profile
        filtered = new FilteredStream(str, objectPublicOnly)
      else
        filtered = new FilteredStream(str, objectRecipientsOnly(profile))
      filtered.getObjects 0, 4, this
    ), ((err, refs) ->
      group = @group()
      throw err  if err
      _.each refs, (ref) ->
        ActivityObject.getObject ref.objectType, ref.id, group()

    ), (err, objs) ->
      if err
        callback err
      else
        obj.replies.items = objs
        _.each obj.replies.items, (item) ->
          item.sanitize()

        callback null


  Step (->
    group = @group()
    _.each objs, (obj) ->
      getReplies obj, group()

  ), callback

firstFewSharesFinisher = (req, collection, callback) ->
  profile = (if (req.remoteUser) then req.remoteUser.profile else null)
  objects = _.pluck(collection.items, "object")
  firstFewShares profile, objects, callback

firstFewShares = (profile, objs, callback) ->
  getShares = (obj, callback) ->
    if not _.has(obj, "shares") or not _.isObject(obj.shares) or (_.has(obj.shares, "totalItems") and obj.shares.totalItems is 0)
      callback null
      return
    Step (->
      obj.getSharesStream this
    ), ((err, str) ->
      throw err  if err
      str.getObjects 0, 4, this
    ), ((err, refs) ->
      group = @group()
      throw err  if err
      _.each refs, (ref) ->
        ActivityObject.getObject ref.objectType, ref.id, group()

    ), (err, objs) ->
      if err
        callback err
      else
        obj.shares.items = objs
        _.each obj.shares.items, (item) ->
          item.sanitize()

        callback null


  Step (->
    group = @group()
    _.each objs, (obj) ->
      getShares obj, group()

  ), callback


# finisher that adds followed flag to stuff
addLikersFinisher = (req, collection, callback) ->
  
  # Ignore for non-users
  addLikers (if (req.remoteUser) then req.remoteUser.profile else null), _.pluck(collection.items, "object"), callback

addLikers = (profile, objects, callback) ->
  liked = _.filter(objects, (object) ->
    _.has(object, "likes") and _.isObject(object.likes) and _.has(object.likes, "totalItems") and _.isNumber(object.likes.totalItems) and object.likes.totalItems > 0
  )
  Step (->
    group = @group()
    _.each liked, (object) ->
      object.getFavoriters 0, 4, group()

  ), (err, likers) ->
    if err
      callback err
    else
      _.each liked, (object, i) ->
        object.likes.items = likers[i]

      callback null


doFinishers = (finishers) ->
  (req, collection, callback) ->
    Step (->
      group = @group()
      _.each finishers, (finisher) ->
        finisher req, collection, group()

    ), callback

exports.addFollowedFinisher = addFollowedFinisher
exports.addFollowed = addFollowed
exports.addLikedFinisher = addLikedFinisher
exports.addLiked = addLiked
exports.firstFewRepliesFinisher = firstFewRepliesFinisher
exports.firstFewReplies = firstFewReplies
exports.firstFewSharesFinisher = firstFewSharesFinisher
exports.firstFewShares = firstFewShares
exports.doFinishers = doFinishers
exports.addLikersFinisher = addLikersFinisher
exports.addLikers = addLikers
exports.addSharedFinisher = addSharedFinisher
exports.addShared = addShared
