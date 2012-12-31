# pumpclient.js
#
# Common utilities for pump.io scripts
#
# Copyright 2011, 2012 StatusNet Inc.
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
http = require("http")
https = require("https")
fs = require("fs")
path = require("path")
Step = require("step")
urlparse = require("url").parse
querystring = require("querystring")
url = require("url")
OAuth = require("oauth").OAuth
_ = require("underscore")
newOAuth = (serverURL, cred) ->
  oa = undefined
  parts = undefined
  parts = urlparse(serverURL)
  oa = new OAuth(parts.protocol + "//" + parts.host + "/oauth/request_token", parts.protocol + "//" + parts.host + "/oauth/access_token", cred.client_id, cred.client_secret, "1.0", null, "HMAC-SHA1", null, # nonce size; use default
    "User-Agent": "pump.io/0.2.0-alpha.1"
  )
  oa

jsonHandler = (callback) ->
  (err, data, response) ->
    obj = undefined
    if err
      callback err, null, null
    else
      try
        obj = JSON.parse(data)
        callback null, obj, response
      catch e
        callback e, null, null

postJSON = (serverUrl, cred, payload, callback) ->
  oa = undefined
  toSend = undefined
  oa = newOAuth(serverUrl, cred)
  toSend = JSON.stringify(payload)
  oa.post serverUrl, cred.token, cred.token_secret, toSend, "application/json", jsonHandler(callback)

postReport = (payload) ->
  (err, res, body) ->
    if err
      if _(payload).has("id")
        console.log "Error posting payload " + payload.id
      else
        console.log "Error posting payload"
      console.error err
    else
      if _(payload).has("id")
        console.log "Results of posting " + payload.id + ": " + body
      else
        console.log "Results of posting: " + body

postArgs = (serverUrl, args, callback) ->
  requestBody = querystring.stringify(args)
  parts = url.parse(serverUrl)
  
  # An object of options to indicate where to post to
  options =
    host: parts.hostname
    port: parts.port
    path: parts.path
    method: "POST"
    headers:
      "Content-Type": "application/x-www-form-urlencoded"
      "Content-Length": requestBody.length
      "User-Agent": "pump.io/0.2.0-alpha.1"

  mod = (if (parts.protocol is "https:") then https else http)
  
  # Set up the request
  req = mod.request(options, (res) ->
    body = ""
    err = null
    res.setEncoding "utf8"
    res.on "data", (chunk) ->
      body = body + chunk

    res.on "error", (err) ->
      callback err, null, null

    res.on "end", ->
      callback err, res, body

  )
  
  # post the data
  req.write requestBody
  req.end()

clientCred = (host, callback) ->
  Step (->
    credFile = path.join(process.env.HOME, ".pump.d", host + ".json")
    fs.readFile credFile, this
  ), ((err, data) ->
    cred = undefined
    throw err  if err
    cred = JSON.parse(data)
    this null, cred
  ), callback

userCred = (username, host, callback) ->
  client = undefined
  Step (->
    clientCred host, this
  ), ((err, result) ->
    throw err  if err
    client = result
    credFile = path.join(process.env.HOME, ".pump.d", host, username + ".json")
    fs.readFile credFile, this
  ), ((err, data) ->
    throw err  if err
    cred = JSON.parse(data)
    _.extend cred, client
    this null, cred
  ), callback

ensureDir = (dirName, callback) ->
  Step (->
    fs.stat dirName, this
  ), ((err, stat) ->
    if err
      if err.code is "ENOENT"
        fs.mkdir dirName, 0700, this
      else
        throw err
    else unless stat.isDirectory()
      throw new Error(dirName + " is not a directory")
    else
      this null
  ), callback

setClientCred = (host, cred, callback) ->
  dirName = path.join(process.env.HOME, ".pump.d")
  fname = path.join(dirName, host + ".json")
  Step (->
    ensureDir dirName, this
  ), ((err) ->
    throw err  if err
    fs.writeFile fname, JSON.stringify(cred), this
  ), ((err) ->
    throw err  if err
    fs.chmod fname, 0600, this
  ), callback

setUserCred = (username, host, cred, callback) ->
  pumpdName = path.join(process.env.HOME, ".pump.d")
  hostdName = path.join(pumpdName, host)
  fname = path.join(hostdName, username + ".json")
  Step (->
    ensureDir pumpdName, this
  ), ((err) ->
    throw err  if err
    ensureDir hostdName, this
  ), ((err) ->
    throw err  if err
    fs.writeFile fname, JSON.stringify(cred), this
  ), ((err) ->
    throw err  if err
    fs.chmod fname, 0600, this
  ), callback

exports.postJSON = postJSON
exports.postReport = postReport
exports.postArgs = postArgs
exports.setClientCred = setClientCred
exports.clientCred = clientCred
exports.userCred = userCred
exports.setUserCred = setUserCred
