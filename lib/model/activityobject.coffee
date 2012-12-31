# activityobject.js
#
# utility superclass for activity stuff
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
databank = require("databank")
_ = require("underscore")
Step = require("step")
NoSuchThingError = databank.NoSuchThingError
AlreadyExistsError = databank.AlreadyExistsError
DatabankObject = databank.DatabankObject
uuid = require("node-uuid")
URLMaker = require("../urlmaker").URLMaker
IDMaker = require("../idmaker").IDMaker
Stamper = require("../stamper").Stamper
Stream = require("./stream").Stream
UnknownTypeError = (type) ->
  Error.captureStackTrace this, UnknownTypeError
  @name = "UnknownTypeError"
  @type = type
  @message = "Unknown type: " + type

UnknownTypeError:: = new Error()
UnknownTypeError::constructor = UnknownTypeError
ActivityObject = (properties) ->
  ActivityObject.init this, properties

ActivityObject.init = DatabankObject.init
ActivityObject:: = new DatabankObject({})
ActivityObject.beforeCreate = (props, callback) ->
  type = @type
  props.objectType = type  unless _.has(props, "objectType")
  now = Stamper.stamp()
  props.published = props.updated = now
  Step (->
    User = require("./user").User
    unless _(props).has("id")
      props._uuid = IDMaker.makeID()
      props.id = ActivityObject.makeURI(type, props._uuid)
      props.links = {}  unless _.has(props, "links")
      props.links.self = href: URLMaker.makeURL("api/" + type + "/" + props._uuid)
      props.likes = url: URLMaker.makeURL("api/" + type + "/" + props._uuid + "/likes")
      props.replies = url: URLMaker.makeURL("api/" + type + "/" + props._uuid + "/replies")
      props.shares = url: URLMaker.makeURL("api/" + type + "/" + props._uuid + "/shares")
      if _.has(props, "author") and _.isObject(props.author)
        if _.has(props.author, "preferredUsername") and _.isString(props.author.preferredUsername)
          props.url = URLMaker.makeURL([props.author.preferredUsername, type, props._uuid].join("/"))
          this null, null
        else
          User.fromPerson props.author.id, this
      else
        this null, null
    else
      
      # For non-new stuff, clear out volatile data
      ActivityObject.trimCollection props, "likes"
      ActivityObject.trimCollection props, "replies"
      ActivityObject.trimCollection props, "shares"
      if _(props).has("replies")
        if _(props.replies).isObject()
          delete props.replies.totalItems

          delete props.replies.items
        else
          delete props.replies
      this null, null
  ), ((err, user) ->
    throw err  if err
    props.url = URLMaker.makeURL([user.nickname, type, props._uuid].join("/"))  if user
    
    # Save the author by reference; don't save the whole thing
    ActivityObject.compressProperty props, "author", @parallel()
    ActivityObject.compressProperty props, "inReplyTo", @parallel()
  ), (err) ->
    if err
      callback err, null
    else
      callback null, props


ActivityObject::afterUpdate = ActivityObject::afterSave = (callback) ->
  @expand callback

ActivityObject::afterGet = (callback) ->
  @inReplyTo = ActivityObject.toObject(@inReplyTo)  if @inReplyTo
  @expand callback

ActivityObject::afterCreate = (callback) ->
  obj = this
  Step (->
    Stream.create
      name: "activityobject:replies:" + obj.id
    , @parallel()
    Stream.create
      name: "activityobject:shares:" + obj.id
    , @parallel()
  ), ((err, replies, shares) ->
    throw err  if err
    obj.expand this
  ), ((err) ->
    throw err  if err
    if not _(obj).has("inReplyTo") or not _(obj.inReplyTo).isObject()
      callback null
    else
      ActivityObject.ensureObject obj.inReplyTo, this
  ), ((err, irt) ->
    throw err  if err
    irt.getRepliesStream this
  ), ((err, replies) ->
    compressed = undefined
    throw err  if err
    compressed =
      id: obj.id
      objectType: obj.objectType

    replies.deliverObject compressed, this
  ), callback

ActivityObject::afterDel = ActivityObject::afterEfface = (callback) ->
  obj = this
  Step (->
    if not _(obj).has("inReplyTo") or not _(obj.inReplyTo).isObject()
      callback null
    else
      ActivityObject.ensureObject obj.inReplyTo, this
  ), ((err, irt) ->
    throw err  if err
    irt.getRepliesStream this
  ), ((err, replies) ->
    compressed = undefined
    throw err  if err
    compressed =
      id: obj.id
      objectType: obj.objectType

    replies.removeObject compressed, this
  ), callback

ActivityObject::expand = (callback) ->
  ActivityObject.expandProperty this, "author", callback

ActivityObject::beforeSave = (callback) ->
  obj = this
  now = Stamper.stamp()
  @updated = now
  ActivityObject.trimCollection this, "likes"
  ActivityObject.trimCollection this, "replies"
  ActivityObject.trimCollection this, "shares"
  
  # Save the author by reference; don't save the whole thing
  Step (->
    
    # Save the author by reference; don't save the whole thing
    ActivityObject.compressProperty obj, "author", this
  ), ((err) ->
    throw err  if err
    ActivityObject.compressProperty obj, "inReplyTo", this
  ), (err) ->
    if err
      callback err, null
    else
      callback null, obj


ActivityObject::beforeUpdate = (props, callback) ->
  immutable = ["id", "objectType", "_uuid", "published"]
  i = undefined
  prop = undefined
  i = 0
  while i < immutable.length
    prop = immutable[i]
    delete props[prop]  if props.hasOwnProperty(prop)
    i++
  ActivityObject.trimCollection props, "likes"
  ActivityObject.trimCollection props, "replies"
  ActivityObject.trimCollection props, "shares"
  now = Stamper.stamp()
  props.updated = now
  Step (->
    
    # Save the author by reference; don't save the whole thing
    ActivityObject.compressProperty props, "author", this
  ), ((err) ->
    throw err  if err
    ActivityObject.compressProperty props, "inReplyTo", this
  ), (err) ->
    if err
      callback err, null
    else
      callback null, props



# For now, we make HTTP URIs. Maybe someday we'll
# do something else. I like HTTP URIs, though.
ActivityObject.makeURI = (type, uuid) ->
  URLMaker.makeURL "api/" + type + "/" + uuid

ActivityObject.toClass = (type) ->
  module = undefined
  className = undefined
  return require("./other").Other  if not type or ActivityObject.objectTypes.indexOf(type.toLowerCase()) is -1
  module = require("./" + type)
  className = type.substring(0, 1).toUpperCase() + type.substring(1, type.length).toLowerCase()
  module[className]

ActivityObject.toObject = (props, defaultType) ->
  Cls = undefined
  type = undefined
  
  # Try rational fallbacks
  type = props.objectType or defaultType or ActivityObject.NOTE
  Cls = ActivityObject.toClass(type)
  new Cls(props)

ActivityObject.getObject = (type, id, callback) ->
  Cls = undefined
  Cls = ActivityObject.toClass(type)
  Cls.get id, callback

ActivityObject.createObject = (obj, callback) ->
  Cls = undefined
  type = obj.objectType
  Cls = ActivityObject.toClass(type)
  Cls.create obj, callback

ActivityObject.ensureObject = (obj, callback) ->
  Cls = undefined
  type = obj.objectType
  id = obj.id
  Cls = ActivityObject.toClass(type)
  Cls.create obj, (err, result) ->
    if err
      if err.name is "AlreadyExistsError"
        Cls.get id, callback
      else
        callback err, null
    else
      callback null, result


ActivityObject.compressProperty = (obj, name, callback) ->
  
  # Easy enough!
  unless _(obj).has(name)
    callback null
    return
  unless _.isObject(obj[name])
    callback new Error("Not an object")
    return
  Step (->
    ActivityObject.ensureObject obj[name], this
  ), (err, sub) ->
    Cls = undefined
    if err
      callback err
    else
      Cls = ActivityObject.toClass(sub.objectType)
      unless Cls
        callback new UnknownTypeError(sub.objectType)
      else
        obj[name] = new Cls(
          id: sub.id
          objectType: sub.objectType
        )
        callback null


ActivityObject.compressArray = (obj, name, callback) ->
  
  # Easy enough!
  unless _(obj).has(name)
    callback null
    return
  unless _(obj[name]).isArray()
    callback new Error("Property '" + name + "' of object '" + obj.id + "' is not an array")
    return
  Step (->
    i = undefined
    group = @group()
    i = 0
    while i < obj[name].length
      ActivityObject.ensureObject obj[name][i], group()
      i++
  ), (err, subs) ->
    Cls = undefined
    if err
      callback err
    else
      obj[name] = new Array(subs.length)
      i = 0
      while i < subs.length
        Cls = ActivityObject.toClass(subs[i].objectType)
        unless Cls
          callback new UnknownTypeError(subs[i].objectType)
          return
        else
          obj[name][i] = new Cls(
            id: subs[i].id
            objectType: subs[i].objectType
          )
        i++
      callback null


ActivityObject.expandProperty = (obj, name, callback) ->
  
  # Easy enough!
  unless _(obj).has(name)
    callback null
    return
  unless _.isObject(obj[name])
    callback new Error("Not an object")
    return
  Step (->
    ActivityObject.ensureObject obj[name], this
  ), (err, sub) ->
    if err
      callback err
    else
      obj[name] = sub
      callback null


ActivityObject.expandArray = (obj, name, callback) ->
  
  # Easy enough!
  unless _(obj).has(name)
    callback null
    return
  unless _(obj[name]).isArray()
    callback new Error("Property '" + name + "' of object '" + obj.id + "' is not an array")
    return
  Step (->
    i = undefined
    group = @group()
    i = 0
    while i < obj[name].length
      ActivityObject.ensureObject obj[name][i], group()
      i++
  ), (err, subs) ->
    Cls = undefined
    if err
      callback err
    else
      obj[name] = subs
      callback null


ActivityObject::favoritedBy = (id, callback) ->
  obj = this
  name = "favoriters:" + obj.id
  Step (->
    Stream.get name, this
  ), ((err, stream) ->
    if err and err.name is "NoSuchThingError"
      Stream.create
        name: name
      , this
    else if err
      throw err
    else
      this null, stream
  ), ((err, stream) ->
    throw err  if err
    stream.deliver id, this
  ), (err) ->
    if err
      callback err
    else
      callback null


ActivityObject::unfavoritedBy = (id, callback) ->
  obj = this
  name = "favoriters:" + obj.id
  Step (->
    Stream.get name, this
  ), ((err, stream) ->
    if err and err.name is "NoSuchThingError"
      Stream.create
        name: name
      , this
    else if err
      throw err
    else
      this null, stream
  ), ((err, stream) ->
    throw err  if err
    stream.remove id, this
  ), (err) ->
    if err
      callback err
    else
      callback null


ActivityObject.getObjectStream = (className, streamName, start, end, callback) ->
  ids = undefined
  Cls = ActivityObject.toClass(className)
  Step (->
    Stream.get streamName, this
  ), ((err, stream) ->
    throw err  if err
    stream.getIDs start, end, this
  ), ((err, results) ->
    throw err  if err
    ids = results
    if ids.length is 0
      callback null, []
    else
      Cls.readAll ids, this
  ), (err, map) ->
    i = undefined
    objects = []
    if err
      if err.name is "NoSuchThingError"
        callback null, []
      else
        callback err, null
    else
      objects = new Array(ids.length)
      
      # Try to get it in the right order
      i = 0
      while i < ids.length
        objects[i] = map[ids[i]]
        i++
      callback null, objects


ActivityObject::getFavoriters = (start, end, callback) ->
  ActivityObject.getObjectStream "person", "favoriters:" + @id, start, end, callback

ActivityObject::favoritersCount = (callback) ->
  Stream.count "favoriters:" + @id, (err, count) ->
    if err and err.name is "NoSuchThingError"
      callback null, 0
    else if err
      callback err, null
    else
      callback null, count


ActivityObject::expandFeeds = (callback) ->
  obj = this
  Step (->
    obj.repliesCount @parallel()
    obj.favoritersCount @parallel()
    obj.sharesCount @parallel()
  ), (err, repliesCount, favoritersCount, sharesCount) ->
    if err
      callback err
    else
      obj.replies.totalItems = repliesCount  if obj.replies
      obj.likes.totalItems = favoritersCount  if obj.likes
      obj.shares.totalItems = sharesCount  if obj.shares
      callback null


ActivityObject::getSharesStream = (callback) ->
  obj = this
  name = "activityobject:shares:" + obj.id
  Stream.get name, callback

ActivityObject::getRepliesStream = (callback) ->
  obj = this
  name = "activityobject:replies:" + obj.id
  Stream.get name, callback

ActivityObject::getReplies = (start, end, callback) ->
  obj = this
  full = []
  Step (->
    obj.getRepliesStream this
  ), ((err, stream) ->
    throw err  if err
    stream.getObjects start, end, this
  ), ((err, compressed) ->
    i = undefined
    group = @group()
    throw err  if err
    i = 0
    while i < compressed.length
      ActivityObject.ensureObject compressed[i], group()
      i++
  ), ((err, results) ->
    i = undefined
    group = @group()
    throw err  if err
    full = results
    i = 0
    while i < full.length
      full[i].expandFeeds group()
      i++
  ), (err) ->
    if err
      callback err, null
    else
      callback null, full


ActivityObject::sharesCount = (callback) ->
  obj = this
  Step (->
    obj.getSharesStream this
  ), ((err, str) ->
    throw err  if err
    str.count this
  ), callback

ActivityObject::repliesCount = (callback) ->
  name = "activityobject:replies:" + @id
  Stream.count name, (err, count) ->
    if err and err.name is "NoSuchThingError"
      callback null, 0
    else if err
      callback err, null
    else
      callback null, count


ActivityObject::keepers = ->
  ["id", "objectType", "author", "published", "updated", "_uuid", "inReplyTo"]


# Default hooks for efface()
ActivityObject::beforeEfface = (callback) ->
  callback null

ActivityObject::efface = (callback) ->
  keepers = @keepers()
  obj = this
  Step (->
    obj.beforeEfface this
  ), ((err) ->
    throw err  if err
    _.each obj, (value, key) ->
      delete obj[key]  unless _.contains(keepers, key)

    now = Stamper.stamp()
    obj.deleted = obj.updated = now
    obj.save this
  ), ((err) ->
    obj.afterEfface this
  ), callback

ActivityObject.canonicalID = (id) ->
  return "acct:" + id  if id.indexOf("@") isnt -1 and id.substr(0, 5) isnt "acct:"
  id

ActivityObject.sameID = (id1, id2) ->
  ActivityObject.canonicalID(id1) is ActivityObject.canonicalID(id2)


# Clean up stuff that shouldn't go through to the outside world.
# By convention, we start these properties with a "_".
ActivityObject::sanitize = ->
  obj = this
  cleanup = []
  _.each obj, (value, key) ->
    delete obj[key]  if key[0] is "_"

  @inReplyTo.sanitize()  if @inReplyTo and @inReplyTo.sanitize
  @author.sanitize()  if @author and @author.sanitize
  return

ActivityObject.trimCollection = (obj, prop) ->
  if _(obj).has(prop)
    if _(obj[prop]).isObject()
      delete obj[prop].totalItems

      delete obj[prop].items
    else
      delete obj[prop]

ActivityObject::isFollowable = ->
  obj = this
  followableTypes = [ActivityObject.PERSON]
  if _.contains(followableTypes, obj.objectType)
    true
  else if _.has(obj, "links") and _.has(obj.links, "activity-outbox")
    true
  else
    false

ActivityObject.objectTypes = ["alert", "application", "article", "audio", "badge", "binary", "bookmark", "collection", "comment", "device", "event", "file", "game", "group", "image", "issue", "job", "note", "offer", "organization", "page", "person", "place", "process", "product", "question", "review", "service", "task", "video"]
objectType = undefined
i = undefined

# Constants-like members for activity object types
i = 0
while i < ActivityObject.objectTypes.length
  objectType = ActivityObject.objectTypes[i]
  ActivityObject[objectType.toUpperCase().replace("-", "_")] = objectType
  i++
ActivityObject.baseSchema =
  pkey: "id"
  fields: ["attachments", "author", "content", "displayName", "downstreamDuplicates", "id", "image", "objectType", "published", "summary", "updated", "upstreamDuplicates", "url", "_uuid"]
  indices: ["_uuid"]

exports.ActivityObject = ActivityObject
exports.UnknownTypeError = UnknownTypeError
