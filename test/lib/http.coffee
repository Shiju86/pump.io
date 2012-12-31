# http.js
#
# HTTP utilities for testing
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
http = require("http")
https = require("https")
assert = require("assert")
querystring = require("querystring")
_ = require("underscore")
Step = require("step")
fs = require("fs")
OAuth = require("oauth").OAuth
urlparse = require("url").parse
OAuthJSONError = (obj) ->
  Error.captureStackTrace this, OAuthJSONError
  @name = "OAuthJSONError"
  _.extend this, obj

OAuthJSONError:: = new Error()
OAuthJSONError::constructor = OAuthJSONError
OAuthJSONError::toString = ->
  "OAuthJSONError (" + @statusCode + "): " + @data

newOAuth = (serverURL, cred) ->
  oa = undefined
  parts = undefined
  parts = urlparse(serverURL)
  oa = new OAuth("http://" + parts.host + "/oauth/request_token", "http://" + parts.host + "/oauth/access_token", cred.consumer_key, cred.consumer_secret, "1.0", null, "HMAC-SHA1", null, # nonce size; use default
    "User-Agent": "pump.io/0.2.0-alpha.1"
  )
  oa

endpoint = (url, hostname, port, methods) ->
  unless port
    methods = hostname
    hostname = "localhost"
    port = 4815
  else unless methods
    methods = port
    port = 80
  context =
    topic: ->
      options hostname, port, url, @callback

    "it exists": (err, allow, res, body) ->
      assert.ifError err
      assert.equal res.statusCode, 200

  checkMethod = (method) ->
    (err, allow, res, body) ->
      assert.include allow, method

  i = undefined
  i = 0
  while i < methods.length
    context["it supports " + methods[i]] = checkMethod(methods[i])
    i++
  context

options = (host, port, path, callback) ->
  reqOpts =
    host: host
    port: port
    path: path
    method: "OPTIONS"
    headers:
      "User-Agent": "pump.io/0.2.0-alpha.1"

  mod = (if (port is 443) then https else http)
  req = mod.request(reqOpts, (res) ->
    body = ""
    res.setEncoding "utf8"
    res.on "data", (chunk) ->
      body = body + chunk

    res.on "error", (err) ->
      callback err, null, null, null

    res.on "end", ->
      allow = []
      if _(res.headers).has("allow")
        allow = res.headers.allow.split(",").map((s) ->
          s.trim()
        )
      callback null, allow, res, body

  )
  req.on "error", (err) ->
    callback err, null, null, null

  req.end()

post = (host, port, path, params, callback) ->
  requestBody = querystring.stringify(params)
  reqOpts =
    hostname: host
    port: port
    path: path
    method: "POST"
    headers:
      "Content-Type": "application/x-www-form-urlencoded"
      "Content-Length": requestBody.length
      "User-Agent": "pump.io/0.2.0-alpha.1"

  mod = (if (port is 443) then https else http)
  req = mod.request(reqOpts, (res) ->
    body = ""
    res.setEncoding "utf8"
    res.on "data", (chunk) ->
      body = body + chunk

    res.on "error", (err) ->
      callback err, null, null

    res.on "end", ->
      callback null, res, body

  )
  req.on "error", (err) ->
    callback err, null, null

  req.write requestBody
  req.end()

jsonHandler = (callback) ->
  (err, data, response) ->
    obj = undefined
    if err
      callback new OAuthJSONError(err), null, null
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

postFile = (serverUrl, cred, fileName, mimeType, callback) ->
  Step (->
    fs.readFile fileName, this
  ), ((err, data) ->
    oa = undefined
    if err
      callback err, null, null
    else
      oa = newOAuth(serverUrl, cred)
      oa.post serverUrl, cred.token, cred.token_secret, data.toString("binary"), mimeType, this
  ), jsonHandler(callback)

putJSON = (serverUrl, cred, payload, callback) ->
  oa = undefined
  toSend = undefined
  oa = newOAuth(serverUrl, cred)
  toSend = JSON.stringify(payload)
  oa.put serverUrl, cred.token, cred.token_secret, toSend, "application/json", jsonHandler(callback)

getJSON = (serverUrl, cred, callback) ->
  oa = undefined
  toSend = undefined
  oa = newOAuth(serverUrl, cred)
  oa.get serverUrl, cred.token, cred.token_secret, jsonHandler(callback)

delJSON = (serverUrl, cred, callback) ->
  oa = undefined
  toSend = undefined
  oa = newOAuth(serverUrl, cred)
  oa["delete"] serverUrl, cred.token, cred.token_secret, jsonHandler(callback)

getfail = (rel, status) ->
  status = 400  unless status
  topic: ->
    callback = @callback
    http.get "http://localhost:4815" + rel, (res) ->
      if res.statusCode isnt status
        callback new Error("Bad status code: " + res.statusCode)
      else
        callback null


  "it fails with the correct error code": (err) ->
    assert.ifError err

dialbackPost = (endpoint, id, token, ts, requestBody, contentType, callback) ->
  reqOpts = urlparse(endpoint)
  auth = undefined
  reqOpts.method = "POST"
  reqOpts.headers =
    "Content-Type": contentType
    "Content-Length": requestBody.length
    "User-Agent": "pump.io/0.2.0-alpha.1"

  if id.indexOf("@") is -1
    auth = "Dialback host=\"" + id + "\", token=\"" + token + "\""
  else
    auth = "Dialback webfinger=\"" + id + "\", token=\"" + token + "\""
  mod = (if (reqOpts.protocol is "https:") then https else http)
  reqOpts.headers["Authorization"] = auth
  reqOpts.headers["Date"] = (new Date(ts)).toUTCString()
  req = mod.request(reqOpts, (res) ->
    body = ""
    res.setEncoding "utf8"
    res.on "data", (chunk) ->
      body = body + chunk

    res.on "error", (err) ->
      callback err, null, null

    res.on "end", ->
      callback null, res, body

  )
  req.on "error", (err) ->
    callback err, null, null

  req.write requestBody
  req.end()

exports.options = options
exports.post = post
exports.postJSON = postJSON
exports.postFile = postFile
exports.getJSON = getJSON
exports.putJSON = putJSON
exports.delJSON = delJSON
exports.endpoint = endpoint
exports.getfail = getfail
exports.dialbackPost = dialbackPost
exports.newOAuth = newOAuth
