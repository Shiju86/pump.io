# lib/filters.js
#
# Some common filters we use on streams
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
Step = require("step")
Activity = require("../lib/model/activity").Activity
ActivityObject = require("../lib/model/activityobject").ActivityObject
recipientsOnly = (person) ->
  (id, callback) ->
    Step (->
      Activity.get id, this
    ), ((err, act) ->
      throw err  if err
      act.checkRecipient person, this
    ), callback


# Just do this one once
publicOnly = recipientsOnly(null)
objectRecipientsOnly = (person) ->
  (item, callback) ->
    ref = undefined
    try
      ref = JSON.parse(item)
    catch err
      callback err, null
      return
    Step (->
      ActivityObject.getObject ref.objectType, ref.id, this
    ), ((err, obj) ->
      throw err  if err
      Activity.postOf obj, this
    ), ((err, act) ->
      throw err  if err
      unless act
        callback null, false
      else
        act.checkRecipient person, this
    ), callback

objectPublicOnly = objectRecipientsOnly(null)
idRecipientsOnly = (person, type) ->
  (id, callback) ->
    Step (->
      ActivityObject.getObject type, id, this
    ), ((err, obj) ->
      throw err  if err
      Activity.postOf obj, this
    ), ((err, act) ->
      throw err  if err
      unless act
        callback null, false
      else
        act.checkRecipient person, this
    ), callback

idPublicOnly = (type) ->
  idRecipientsOnly null, type


# In case you need one, here it is
always = (id, callback) ->
  callback null, true

exports.recipientsOnly = recipientsOnly
exports.publicOnly = publicOnly
exports.objectRecipientsOnly = objectRecipientsOnly
exports.objectPublicOnly = objectPublicOnly
exports.idRecipientsOnly = idRecipientsOnly
exports.idPublicOnly = idPublicOnly
exports.always = always
