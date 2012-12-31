# share.js
#
# A share by a person of an object
#
# Copyright 2012 StatusNet Inc.
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
DatabankObject = require("databank").DatabankObject
IDMaker = require("../idmaker").IDMaker
Stamper = require("../stamper").Stamper
ActivityObject = require("./activityobject").ActivityObject
Share = DatabankObject.subClass("share")
exports.Share = Share
Share.schema =
  pkey: "id"
  fields: ["sharer", "shared", "published", "updated"]
  indices: ["sharer.id", "shared.id"]

Share.id = (sharer, shared) ->
  sharer.id + "♻" + shared.id

Share.beforeCreate = (props, callback) ->
  if not _(props).has("sharer") or not _(props.sharer).has("id") or not _(props.sharer).has("objectType") or not _(props).has("shared") or not _(props.shared).has("id") or not _(props.shared).has("objectType")
    callback new Error("Invalid Share"), null
    return
  now = Stamper.stamp()
  props.published = props.updated = now
  props.id = Share.id(props.sharer, props.shared)
  Step (->
    
    # Save the author by reference; don't save the whole thing
    ActivityObject.compressProperty props, "sharer", @parallel()
    ActivityObject.compressProperty props, "shared", @parallel()
  ), (err) ->
    if err
      callback err, null
    else
      callback null, props

  callback null, props

Share::beforeUpdate = (props, callback) ->
  immutable = ["sharer", "shared", "id", "published"]
  i = undefined
  prop = undefined
  i = 0
  while i < immutable.length
    prop = immutable[i]
    delete props[prop]  if _(props).has(prop)
    i++
  now = Stamper.stamp()
  props.updated = now
  
  # XXX: store sharer, to by reference
  callback null, props

Share::beforeSave = (callback) ->
  share = this
  if not _(share).has("sharer") or not _(share.sharer).has("id") or not _(share.sharer).has("objectType") or not _(share).has("shared") or not _(share.shared).has("id") or not _(share.shared).has("objectType")
    callback new Error("Invalid Share"), null
    return
  now = Stamper.stamp()
  share.updated = now
  unless _(share).has("id")
    share.id = Share.id(share.sharer, share.shared)
    share.published = now  unless _(share).has("published")
  callback null

Share::expand = (callback) ->
  share = this
  Step (->
    ActivityObject.expandProperty share, "sharer", @parallel()
    ActivityObject.expandProperty share, "shared", @parallel()
  ), callback
