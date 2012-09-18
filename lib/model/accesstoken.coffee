# accesstoken.js
#
# An OAuth request token
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
Stamper = require("../stamper").Stamper
Step = require("step")
randomString = require("../randomstring").randomString
NoSuchThingError = databank.NoSuchThingError
AccessToken = DatabankObject.subClass("accesstoken")
AccessToken.schema =
  pkey: "access_token"
  fields: ["token_secret", "consumer_key", "request_token", "username", "created", "updated"]
  indices: ["username", "consumer_key", "request_token"]

exports.AccessToken = AccessToken
AccessToken.pkey = ->
  "access_token"

AccessToken.defaultCreate = AccessToken.create
AccessToken.create = (properties, callback) ->
  unless _(properties).has("consumer_key")
    callback new Error("Gotta have a consumer key."), null
    return
  unless _(properties).has("request_token")
    callback new Error("Gotta have a request token."), null
    return
  unless _(properties).has("username")
    callback new Error("Gotta have a username."), null
    return
  Step (->
    randomString 16, @parallel()
    randomString 32, @parallel()
  ), (err, token, token_secret) ->
    if err
      callback err, null
    else
      now = Stamper.stamp()
      _(properties).extend
        access_token: token
        token_secret: token_secret
        created: now
        updated: now

      AccessToken.defaultCreate properties, callback

