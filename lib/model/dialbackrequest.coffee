# dialbackclientrequest.js
#
# Keep track of the requests we've made
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
DatabankObject = databank.DatabankObject
Step = require("step")
randomString = require("../randomstring").randomString
Stream = require("./stream").Stream
NoSuchThingError = databank.NoSuchThingError
DialbackRequest = DatabankObject.subClass("dialbackrequest")
DialbackRequest.schema =
  pkey: "endpoint_id_token_timestamp"
  fields: ["endpoint", "id", "token", "timestamp"]

exports.DialbackRequest = DialbackRequest
DialbackRequest.toKey = (props) ->
  props.endpoint + "/" + props.id + "/" + props.token + "/" + props.timestamp

DialbackRequest.beforeCreate = (props, callback) ->
  if not _(props).has("endpoint") or not _(props).has("id") or not _(props).has("token") or not _(props).has("timestamp")
    callback new Error("Wrong properties"), null
    return
  props.endpoint_id_token_timestamp = DialbackRequest.toKey(props)
  callback null, props


# We keep a stream of all requests for cleanup
DialbackRequest::afterCreate = (callback) ->
  req = this
  Step (->
    DialbackRequest.stream this
  ), ((err, str) ->
    throw err  if err
    str.deliver req.endpoint_id_token_timestamp, this
  ), callback

DialbackRequest.cleanup = (callback) ->
  cleanupFirst = (str, callback) ->
    ids = undefined
    cleaned = undefined
    Step (->
      str.getIDs 0, 20, this
    ), ((err, res) ->
      throw err  if err
      ids = res
      if ids.length is 0
        cb null
      else
        cleanupIDs ids, this
    ), ((err, res) ->
      throw err  if err
      cleaned = res
      cleanupRest str, ids[ids.length - 1], this
    ), ((err) ->
      throw err  if err
      removeIDs str, cleaned, this
    ), callback

  cleanupRest = (str, key, callback) ->
    ids = undefined
    cleaned = undefined
    Step (->
      str.getIDsGreaterThan key, 20, this
    ), ((err, res) ->
      throw err  if err
      ids = res
      if ids.length is 0
        callback null
      else
        cleanupIDs ids, this
    ), ((err, res) ->
      throw err  if err
      cleaned = res
      cleanupRest str, ids[ids.length - 1], this
    ), ((err) ->
      throw err  if err
      removeIDs str, cleaned, this
    ), callback

  maybeCleanup = (id, callback) ->
    Step (->
      DialbackRequest.get id, this
    ), ((err, req) ->
      if err and (err.name is "NoSuchThingError")
        callback null, true
      else if err
        callback err, null
      else
        if Date.now() - req.timestamp > 300000
          req.del this
        else
          callback null, false
    ), (err) ->
      if err
        callback err, null
      else
        callback null, true


  cleanupIDs = (ids, callback) ->
    Step (->
      i = undefined
      group = @group()
      i = 0
      while i < ids.length
        maybeCleanup ids[i], group()
        i++
    ), ((err, cleanedUp) ->
      i = undefined
      toRemove = []
      throw err  if err
      i = 0
      while i < ids.length
        toRemove.push ids[i]  if cleanedUp[i]
        i++
      callback null, toRemove
    ), callback

  maybeRemove = (str, id, callback) ->
    Step (->
      str.remove id, this
    ), (err) ->
      if err and err.name is "NotInStreamError"
        callback null
      else if err
        callback err
      else
        callback null


  removeIDs = (str, ids, callback) ->
    Step (->
      i = undefined
      group = @group()
      i = 0
      while i < ids.length
        maybeRemove str, ids[i], group()
        i++
    ), (err, ids) ->
      if err
        callback err
      else
        callback null


  Step (->
    DialbackRequest.stream this
  ), ((err, str) ->
    throw err  if err
    cleanupFirst str, this
  ), (err) ->
    if err
      callback err
    else
      callback null


DialbackRequest.stream = (callback) ->
  name = "dialbackclientrequest:recent"
  Step (->
    Stream.get name, this
  ), ((err, str) ->
    if err
      if err.name is "NoSuchThingError"
        Stream.create
          name: name
        , this
      else
        throw err
    else
      callback null, str
  ), (err, str) ->
    if err
      if err.name is "AlreadyExistsError"
        Stream.get name, callback
      else
        callback err
    else
      callback null, str



# Clear out old requests every 1 minute
setInterval (->
  
  # XXX: log errors
  DialbackRequest.cleanup (err) ->

), 60000
