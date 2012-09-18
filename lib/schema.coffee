# lib/schema.js
#
# Get all the files
#
# Copyright 2011-2012, StatusNet Inc.
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
Activity = require("./model/activity").Activity
ActivityObject = require("./model/activityobject").ActivityObject
User = require("./model/user").User
Edge = require("./model/edge").Edge
Stream = require("./model/stream").Stream
Client = require("./model/client").Client
RequestToken = require("./model/requesttoken").RequestToken
AccessToken = require("./model/accesstoken").AccessToken
Nonce = require("./model/nonce").Nonce
getSchema = ->
  i = undefined
  type = undefined
  Cls = undefined
  schema = {}
  schema.activity = Activity.schema
  schema.user = User.schema
  schema.edge = Edge.schema
  schema.userlist = pkey: "id"
  schema.usercount = pkey: "id"
  _.extend schema, Stream.schema
  schema[Client.type] = Client.schema
  schema[RequestToken.type] = RequestToken.schema
  schema[AccessToken.type] = AccessToken.schema
  schema[Nonce.type] = Nonce.schema
  i = 0
  while i < ActivityObject.objectTypes.length
    type = ActivityObject.objectTypes[i]
    Cls = ActivityObject.toClass(type)
    if Cls.schema
      schema[type] = Cls.schema
    else
      schema[type] =
        pkey: "id"
        fields: ["updated", "published", "displayName", "url"]
        indices: ["uuid", "author.id"]
    i++
  schema

exports.schema = getSchema()
