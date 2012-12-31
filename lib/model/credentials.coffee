# Credentials for a remote system
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
Step = require("step")
databank = require("databank")
_ = require("underscore")
wf = require("webfinger")
querystring = require("querystring")
urlparse = require("url").parse
DialbackClient = require("../dialbackclient")
Stamper = require("../stamper").Stamper
ActivityObject = require("./activityobject").ActivityObject
DatabankObject = databank.DatabankObject
NoSuchThingError = databank.NoSuchThingError
Credentials = DatabankObject.subClass("credentials")
Credentials.schema =
  pkey: "host_and_id"
  fields: ["host", "id", "client_id", "client_secret", "expires_at", "created", "updated"]
  indices: ["host", "id", "client_id"]

Credentials.makeKey = (host, id) ->
  unless id
    host
  else
    host + "/" + id

Credentials.beforeCreate = (props, callback) ->
  props.created = props.updated = Stamper.stamp()
  props.host_and_id = Credentials.makeKey(props.host, props.id)
  callback null, props

Credentials::beforeUpdate = (props, callback) ->
  props.updated = Stamper.stamp()
  callback null, props

Credentials.hostOf = (endpoint) ->
  parts = urlparse(endpoint)
  parts.hostname

Credentials.getFor = (id, endpoint, callback) ->
  host = Credentials.hostOf(endpoint)
  toSend = undefined
  id = ActivityObject.canonicalID(id)
  Step (->
    Credentials.get Credentials.makeKey(host, id), this
  ), ((err, cred) ->
    unless err
      
      # if it worked, just return the credentials
      callback null, cred
    else unless err.name is "NoSuchThingError"
      throw err
    else
      wf.hostmeta host, this
  ), ((err, jrd) ->
    reg = undefined
    body = undefined
    throw err  if err
    if not _(jrd).has("links") or not _(jrd.links).isArray()
      callback new Error("Can't get credentials for " + host), null
      return
    else
      
      # Get the credentialses
      reg = jrd.links.filter((link) ->
        link.hasOwnProperty("rel") and link.rel is "registration_endpoint" and link.hasOwnProperty("href")
      )
      if reg.length is 0
        callback new Error("Can't get credentials for " + host), null
        return
      body = querystring.stringify(type: "client_associate")
      if id.substr(0, 5) is "acct:"
        toSend = id.substr(5)
      else
        toSend = id
      DialbackClient.post reg[0].href, toSend, body, "application/x-www-form-urlencoded", this
  ), ((err, resp, body) ->
    props = undefined
    throw err  if err
    
    # XXX: check response content type
    # may throw parse error
    try
      props = JSON.parse(body)
    catch err
      throw err
    props.id = id
    props.host = host
    Credentials.create props, this
  ), (err, cred) ->
    if err
      callback err, null
    else
      callback null, cred


exports.Credentials = Credentials
