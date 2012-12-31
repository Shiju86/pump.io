# stream.js
#
# A (potentially very long) stream of object IDs
#
# Copyright 2011,2012 StatusNet Inc.
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
Schlock = require("schlock")
DatabankObject = databank.DatabankObject
IDMaker = require("../idmaker").IDMaker
NoSuchThingError = databank.NoSuchThingError
DatabankError = databank.DatabankError
Stream = DatabankObject.subClass("stream")
Stream.SOFT_LIMIT = 1000
Stream.HARD_LIMIT = 2000
NotInStreamError = (id, streamName) ->
  Error.captureStackTrace this, NotInStreamError
  @name = "NotInStreamError"
  @id = id
  @streamName = streamName
  @message = "id '" + id + "' not found in stream '" + streamName + "'"

NotInStreamError:: = new DatabankError()
NotInStreamError::constructor = NotInStreamError

# Global locking system for streams
Stream.schlock = new Schlock()
Stream.beforeCreate = (props, callback) ->
  bank = Stream.bank()
  stream = null
  schlocked = false
  id = undefined
  unless props.name
    callback new Error("Gotta have a name"), null
    return
  id = props.name + ":stream:" + IDMaker.makeID()
  Step (->
    Stream.schlock.writeLock props.name, this
  ), ((err) ->
    throw err  if err
    schlocked = true
    bank.create "streamsegmentcount", id, 0, @parallel()
    bank.create "streamsegment", id, [], @parallel()
  ), ((err, cnt, seg) ->
    throw err  if err
    bank.create "streamcount", props.name, 0, @parallel()
    bank.create "streamsegments", props.name, [id], @parallel()
  ), ((err, count, segments) ->
    throw err  if err
    Stream.schlock.writeUnlock props.name, this
  ), (err) ->
    if err
      if schlocked
        Stream.schlock.writeUnlock props.name, (err2) ->
          callback err, null

      else
        callback err, null
    else
      callback null, props



# put something in the stream
randBetween = (min, max) ->
  diff = max - min + 1
  Math.floor (Math.random() * diff) + min

Stream::deliver = (id, callback) ->
  stream = this
  bank = Stream.bank()
  schlocked = false
  current = null
  Step (->
    Stream.schlock.writeLock stream.name, this
  ), ((err) ->
    throw err  if err
    schlocked = true
    bank.item "streamsegments", stream.name, 0, this
  ), ((err, id) ->
    throw err  if err
    current = id
    bank.read "streamsegmentcount", current, this
  ), ((err, cnt) ->
    throw err  if err
    
    # Once we hit the soft limit, we start thinking about 
    # a new segment. To avoid conflicts, a bit, we do it at a
    # random point between soft and hard limit. If we actually
    # hit the hard limit, force it.
    if cnt > Stream.SOFT_LIMIT and (cnt > Stream.HARD_LIMIT or randBetween(0, Stream.HARD_LIMIT - Stream.SOFT_LIMIT) is 0)
      stream.newSegmentLockless this
    else
      this null, current
  ), ((err, segmentId) ->
    throw err  if err
    bank.prepend "streamsegment", segmentId, id, @parallel()
    bank.incr "streamsegmentcount", segmentId, @parallel()
    bank.incr "streamcount", stream.name, @parallel()
  ), ((err) ->
    throw err  if err
    Stream.schlock.writeUnlock stream.name, this
  ), (err) ->
    if err
      if schlocked
        Stream.schlock.writeUnlock stream.name, (err2) ->
          callback err, null

      else
        callback err, null
    else
      callback null


Stream::remove = (id, callback) ->
  stream = this
  bank = Stream.bank()
  current = null
  schlocked = false
  segments = undefined
  segmentId = undefined
  Step (->
    Stream.schlock.writeLock stream.name, this
  ), ((err) ->
    throw err  if err
    schlocked = true
    bank.read "streamsegments", stream.name, this
  ), ((err, segments) ->
    i = undefined
    cb = this
    findFrom = (j) ->
      if j >= segments.length
        cb new NotInStreamError(id, stream.name), null
        return
      bank.indexOf "streamsegment", segments[j], id, (err, idx) ->
        if err
          cb err, null
        else if idx is -1
          findFrom j + 1
        else
          cb null, segments[j]


    throw err  if err
    findFrom 0
  ), ((err, found) ->
    throw err  if err
    segmentId = found
    bank.remove "streamsegment", segmentId, id, this
  ), ((err) ->
    throw err  if err
    bank.decr "streamsegmentcount", segmentId, @parallel()
    bank.decr "streamcount", stream.name, @parallel()
  ), ((err) ->
    throw err  if err
    Stream.schlock.writeUnlock stream.name, this
  ), (err) ->
    if err
      if schlocked
        Stream.schlock.writeUnlock stream.name, (err2) ->
          callback err, null

      else
        callback err, null
    else
      callback null


Stream::newSegment = (callback) ->
  stream = this
  schlocked = false
  Step (->
    Stream.schlock.writeLock stream.name, this
  ), ((err) ->
    throw err  if err
    stream.newSegmentLockless this
  ), ((err, segments) ->
    throw err  if err
    Stream.schlock.writeUnlock stream.name, this
  ), (err) ->
    if err
      if schlocked
        Stream.schlock.writeUnlock stream.name, (err2) ->
          callback err, null

      else
        callback err, null
    else
      callback err, id


Stream::newSegmentLockless = (callback) ->
  bank = Stream.bank()
  stream = this
  id = stream.name + ":stream:" + IDMaker.makeID()
  Step (->
    bank.create "streamsegmentcount", id, 0, @parallel()
    bank.create "streamsegment", id, [], @parallel()
  ), ((err, cnt, segment) ->
    throw err  if err
    bank.prepend "streamsegments", stream.name, id, this
  ), (err) ->
    if err
      callback err, null
    else
      callback err, id


Stream::getItems = (start, end, callback) ->
  bank = Stream.bank()
  stream = this
  ids = undefined
  schlocked = undefined
  Step (->
    Stream.schlock.readLock stream.name, this
  ), ((err) ->
    throw err  if err
    schlocked = true
    stream.getItemsLockless start, end, this
  ), ((err, results) ->
    throw err  if err
    ids = results
    Stream.schlock.readUnlock stream.name, this
  ), (err) ->
    if err
      if schlocked
        Stream.schlock.readUnlock stream.name, (err2) ->
          callback err, null

      else
        callback err, null
    else
      callback null, ids


Stream::getItemsLockless = (start, end, callback) ->
  bank = Stream.bank()
  stream = this
  ids = undefined
  getMore = getMore = (segments, start, end, callback) ->
    tip = undefined
    if segments.length is 0
      callback null, []
      return
    tip = segments.shift()
    Step (->
      bank.read "streamsegmentcount", tip, this
    ), ((err, tipcount) ->
      group = @group()
      throw err  if err
      bank.slice "streamsegment", tip, start, Math.min(end, tipcount), group()  if start < tipcount
      if end > tipcount
        if segments.length > 0
          getMore segments, Math.max(start - tipcount, 0), end - tipcount, group()
        else # Asking for more than we have
          # Need to trigger the rest
          group() null, []
    ), (err, parts) ->
      if err
        callback err, null
      else if _(parts).isNull() or _(parts).isUndefined() or _(parts).isEmpty()
        callback new Error("Bad results for segment " + tip + ", start = " + start + ", end = " + end), null
      else
        callback null, (if (parts.length is 1) then parts[0] else parts[0].concat(parts[1]))


  if start < 0 or end < 0 or start > end
    callback new Error("Bad parameters"), null
    return
  Step (->
    
    # XXX: maybe just take slice from [0, end/HARD_LIMIT)
    bank.read "streamsegments", stream.name, this
  ), ((err, segments) ->
    throw err  if err
    getMore segments, start, end, this
  ), (err, ids) ->
    if err
      callback err, null
    else
      callback null, ids



# XXX: Not atomic; can get out of whack if an insertion
# happens between indexOf() and getItems()
Stream::getItemsGreaterThan = (id, count, callback) ->
  stream = this
  ids = undefined
  schlocked = false
  if count < 0
    callback new Error("count must be >= 0)"), null
    return
  Step (->
    Stream.schlock.readLock stream.name, this
  ), ((err) ->
    throw err  if err
    schlocked = true
    stream.indexOfLockless id, this
  ), ((err, idx) ->
    throw err  if err
    stream.getItemsLockless idx + 1, idx + count + 1, this
  ), ((err, results) ->
    throw err  if err
    ids = results
    Stream.schlock.readUnlock stream.name, this
  ), (err) ->
    if err
      if schlocked
        Stream.schlock.readUnlock stream.name, (err2) ->
          callback err, null

      else
        callback err, null
    else
      callback null, ids



# XXX: Not atomic; can get out of whack if an insertion
# happens between indexOf() and getItems()
Stream::getItemsLessThan = (id, count, callback) ->
  stream = this
  ids = undefined
  schlocked = false
  Step (->
    Stream.schlock.readLock stream.name, this
  ), ((err) ->
    throw err  if err
    schlocked = true
    stream.indexOfLockless id, this
  ), ((err, idx) ->
    throw err  if err
    stream.getItemsLockless Math.max(0, idx - count), idx, this
  ), ((err, results) ->
    throw err  if err
    ids = results
    Stream.schlock.readUnlock stream.name, this
  ), (err) ->
    if err
      if schlocked
        Stream.schlock.readUnlock stream.name, (err2) ->
          callback err, null

      else
        callback err, null
    else
      callback null, ids


Stream::indexOf = (id, callback) ->
  stream = this
  schlocked = false
  idx = undefined
  Step (->
    Stream.schlock.readLock stream.name, this
  ), ((err) ->
    throw err  if err
    schlocked = true
    stream.indexOfLockless id, this
  ), ((err, results) ->
    throw err  if err
    idx = results
    Stream.schlock.readUnlock stream.name, this
  ), (err) ->
    if err
      if schlocked
        Stream.schlock.readUnlock stream.name, (err2) ->
          callback err, null

      else
        callback err, null
    else
      callback null, idx


Stream::indexOfLockless = (id, callback) ->
  bank = Stream.bank()
  stream = this
  indexOfSeg = indexOfSeg = (id, segments, offset, callback) ->
    tip = undefined
    cnt = undefined
    if segments.length is 0
      callback null, -1
      return
    tip = segments.shift()
    Step (->
      bank.read "streamsegmentcount", tip, this
    ), ((err, result) ->
      throw err  if err
      cnt = result
      bank.indexOf "streamsegment", tip, id, this
    ), (err, idx) ->
      if err
        callback err, null
      else if idx is -1
        indexOfSeg id, segments, offset + cnt, callback
      else
        callback null, idx + offset


  Step (->
    
    # XXX: maybe just take slice from [0, end/HARD_LIMIT)
    bank.read "streamsegments", stream.name, this
  ), ((err, segments) ->
    throw err  if err
    indexOfSeg id, segments, 0, this
  ), (err, idx) ->
    if err
      callback err, null
    else if idx is -1
      callback new NotInStreamError(id, stream.name), null
    else
      callback null, idx


Stream::count = (callback) ->
  Stream.count @name, callback

Stream.count = (name, callback) ->
  bank = Stream.bank()
  bank.read "streamcount", name, callback

Stream::getIDs = (start, end, callback) ->
  @getItems start, end, callback

Stream::getIDsGreaterThan = (id, count, callback) ->
  @getItemsGreaterThan id, count, callback

Stream::getIDsLessThan = (id, count, callback) ->
  @getItemsLessThan id, count, callback

Stream::getObjects = (start, end, callback) ->
  stream = this
  Step (->
    stream.getItems start, end, this
  ), (err, items) ->
    i = undefined
    objs = undefined
    if err
      callback err, null
    else
      objs = new Array(items.length)
      i = 0
      while i < items.length
        objs[i] = JSON.parse(items[i])
        i++
      callback err, objs


Stream::getObjectsGreaterThan = (obj, count, callback) ->
  stream = this
  Step (->
    stream.getItemsGreaterThan JSON.stringify(obj), count, this
  ), (err, items) ->
    i = undefined
    objs = undefined
    if err
      callback err, null
    else
      objs = new Array(items.length)
      i = 0
      while i < items.length
        objs[i] = JSON.parse(items[i])
        i++
      callback err, objs


Stream::getObjectsLessThan = (obj, count, callback) ->
  stream = this
  Step (->
    stream.getItemsLessThan JSON.stringify(obj), count, this
  ), (err, items) ->
    i = undefined
    objs = undefined
    if err
      callback err, null
    else
      objs = new Array(items.length)
      i = 0
      while i < items.length
        objs[i] = JSON.parse(items[i])
        i++
      callback err, objs


Stream::deliverObject = (obj, callback) ->
  @deliver JSON.stringify(obj), callback

Stream::removeObject = (obj, callback) ->
  @remove JSON.stringify(obj), callback

Stream.schema =
  stream:
    pkey: "name"

  streamcount:
    pkey: "name"

  streamsegments:
    pkey: "name"

  streamsegment:
    pkey: "id"

  streamsegmentcount:
    pkey: "id"

exports.Stream = Stream
exports.NotInStreamError = NotInStreamError
