# dialback.js
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
Step = require("step")
wf = require("webfinger")
http = require("http")
https = require("https")
url = require("url")
URLMaker = require("./urlmaker").URLMaker
querystring = require("querystring")
path = require("path")
DialbackRequest = require("./model/dialbackrequest").DialbackRequest
discoverHostEndpoint = (host, callback) ->
  Step (->
    wf.hostmeta host, this
  ), (err, jrd) ->
    dialbacks = undefined
    if err
      callback err, null
      return
    unless jrd.hasOwnProperty("links")
      callback new Error("No links in host-meta for " + host), null
      return
    dialbacks = jrd.links.filter((link) ->
      link.hasOwnProperty("rel") and link.rel is "dialback" and link.hasOwnProperty("href")
    )
    if dialbacks.length is 0
      callback new Error("No dialback links in host-meta for " + host), null
      return
    callback null, dialbacks[0].href


discoverWebfingerEndpoint = (address, callback) ->
  Step (->
    wf.webfinger address, this
  ), (err, jrd) ->
    dialbacks = undefined
    if err
      callback err, null
      return
    unless jrd.hasOwnProperty("links")
      callback new Error("No links in lrdd for " + address), null
      return
    dialbacks = jrd.links.filter((link) ->
      link.hasOwnProperty("rel") and link.rel is "dialback"
    )
    if dialbacks.length is 0
      callback new Error("No dialback links in lrdd for " + address), null
      return
    callback null, dialbacks[0].href


discoverEndpoint = (fields, callback) ->
  if fields.hasOwnProperty("host")
    discoverHostEndpoint fields.host, callback
  else discoverWebfingerEndpoint fields.webfinger, callback  if fields.hasOwnProperty("webfinger")

postToEndpoint = (endpoint, params, callback) ->
  options = url.parse(endpoint)
  pstring = querystring.stringify(params)
  options.method = "POST"
  options.headers = "Content-Type": "application/x-www-form-urlencoded"
  mod = (if (options.protocol is "https://") then https else http)
  req = mod.request(options, (res) ->
    body = ""
    res.setEncoding "utf8"
    res.on "data", (chunk) ->
      body = body + chunk

    res.on "error", (err) ->
      callback err, null, null

    res.on "end", ->
      if res.statusCode < 200 or res.statusCode > 300
        callback new Error("Error " + res.statusCode + ": " + body), null, null
      else
        callback null, body, res

  )
  req.on "error", (err) ->
    callback err, null, null

  req.write pstring
  req.end()


# XXX: separate request store
requests = {}
saveRequest = (id, url, date, token, callback) ->
  ms = Date.parse(date)
  props =
    endpoint: url
    id: id
    token: token
    timestamp: ms

  Step (->
    DialbackRequest.create props, this
  ), (err, req) ->
    callback err


seenRequest = (id, url, date, token, callback) ->
  ms = Date.parse(date)
  props =
    endpoint: url
    id: id
    token: token
    timestamp: ms

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


maybeDialback = (req, res, next) ->
  unless req.headers.hasOwnProperty("authorization")
    next()
    return
  dialback req, res, next

dialback = (req, res, next) ->
  auth = undefined
  now = Date.now()
  fields = undefined
  unauthorized = ->
    res.status 401
    res.setHeader "WWW-Authentication", "Dialback"
    res.setHeader "Content-Type", "text/plain"
    res.send "Unauthorized"

  parseFields = (str) ->
    fstr = str.substr(9) # everything after "Dialback "
    pairs = fstr.split(/,\s+/) # XXX: won't handle blanks inside values well
    fields = {}
    pairs.forEach (pair) ->
      kv = pair.split("=")
      key = kv[0]
      value = kv[1].replace(/^"|"$/g, "")
      fields[key] = value

    fields

  unless req.headers.hasOwnProperty("authorization")
    unauthorized()
    return
  auth = req.headers.authorization
  unless auth.substr(0, 9) is "Dialback "
    unauthorized()
    return
  fields = parseFields(auth)
  
  # must have a token
  unless fields.hasOwnProperty("token")
    unauthorized()
    return
  
  # must have a webfinger or host field
  if not fields.hasOwnProperty("host") and not fields.hasOwnProperty("webfinger")
    unauthorized()
    return
  fields.url = URLMaker.makeURL(req.originalUrl)
  unless req.headers.hasOwnProperty("date")
    unauthorized()
    return
  fields.date = req.headers.date
  if Math.abs(Date.parse(fields.date) - now) > 300000 # 5-minute window
    unauthorized()
    return
  Step (->
    seenRequest fields.host or fields.webfinger, fields.url, fields.date, fields.token, this
  ), ((err, seen) ->
    throw err  if err
    if seen
      unauthorized()
      return
    else
      saveRequest fields.host or fields.webfinger, fields.url, fields.date, fields.token, this
  ), ((err) ->
    throw err  if err
    discoverEndpoint fields, this
  ), ((err, endpoint) ->
    throw err  if err
    postToEndpoint endpoint, fields, this
  ), (err, body, res) ->
    if err
      unauthorized()
    else if fields.hasOwnProperty("host")
      req.remoteHost = fields.host
      next()
    else if fields.hasOwnProperty("webfinger")
      req.remoteUser = fields.webfinger
      next()


exports.dialback = dialback
exports.maybeDialback = maybeDialback
