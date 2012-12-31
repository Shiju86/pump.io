# Dialback HTTP calls
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
_ = require("underscore")
urlparse = require("url").parse
http = require("http")
https = require("https")
DialbackRequest = require("./model/dialbackrequest").DialbackRequest
randomString = require("./randomstring").randomString
DialbackClient =
  post: (endpoint, id, requestBody, contentType, callback) ->
    reqOpts = urlparse(endpoint)
    auth = undefined
    token = undefined
    ts = undefined
    Step (->
      randomString 8, this
    ), ((err, str) ->
      throw err  if err
      token = str
      ts = Math.round(Date.now() / 1000) * 1000
      DialbackClient.remember endpoint, id, token, ts, this
    ), ((err) ->
      if err
        callback err, null, null
        return
      reqOpts.method = "POST"
      reqOpts.headers =
        "Content-Type": contentType
        "Content-Length": requestBody.length
        "User-Agent": "pump.io/0.2.0-alpha.1"

      if id.indexOf("@") is -1
        auth = "Dialback host=\"" + id + "\", token=\"" + token + "\""
      else
        auth = "Dialback webfinger=\"" + id + "\", token=\"" + token + "\""
      reqOpts.headers["Authorization"] = auth
      reqOpts.headers["Date"] = (new Date(ts)).toUTCString()
      req = http.request(reqOpts, this)
      req.on "error", (err) ->
        callback err, null, null

      req.write requestBody
      req.end()
    ), (res) ->
      body = ""
      res.setEncoding "utf8"
      res.on "data", (chunk) ->
        body = body + chunk

      res.on "error", (err) ->
        callback err, null, null

      res.on "end", ->
        callback null, res, body



  remember: (endpoint, id, token, ts, callback) ->
    props =
      endpoint: endpoint
      id: id
      token: token
      timestamp: ts

    Step (->
      DialbackRequest.create props, this
    ), (err, req) ->
      callback err


  isRemembered: (endpoint, id, token, ts, callback) ->
    props =
      endpoint: endpoint
      id: id
      token: token
      timestamp: ts

    key = DialbackRequest.toKey(props)
    Step (->
      DialbackRequest.get key, this
    ), (err, req) ->
      if err and (err.name is "NoSuchThingError")
        callback null, false
      else if err
        callback err, null
      else
        callback null, true


module.exports = DialbackClient
