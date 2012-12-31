# oauth.js
#
# Utilities for generating clients, request tokens, and access tokens
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
cp = require("child_process")
path = require("path")
Step = require("step")
_ = require("underscore")
http = require("http")
OAuth = require("oauth").OAuth
Browser = require("zombie")
httputil = require("./http")
OAuthError = (obj) ->
  Error.captureStackTrace this, OAuthError
  @name = "OAuthError"
  _.extend this, obj

OAuthError:: = new Error()
OAuthError::constructor = OAuthError
OAuthError::toString = ->
  "OAuthError (" + @statusCode + "):" + @data

requestToken = (cl, hostname, port, cb) ->
  oa = undefined
  proto = undefined
  unless port
    cb = hostname
    hostname = "localhost"
    port = 4815
  proto = (if (port is 443) then "https" else "http")
  oa = new OAuth(proto + "://" + hostname + ":" + port + "/oauth/request_token", proto + "://" + hostname + ":" + port + "/oauth/access_token", cl.client_id, cl.client_secret, "1.0", "oob", "HMAC-SHA1", null, # nonce size; use default
    "User-Agent": "pump.io/0.2.0-alpha.1"
  )
  oa.getOAuthRequestToken (err, token, secret) ->
    if err
      cb new OAuthError(err), null
    else
      cb null,
        token: token
        token_secret: secret



newClient = (hostname, port, cb) ->
  unless port
    cb = hostname
    hostname = "localhost"
    port = 4815
  httputil.post hostname, port, "/api/client/register",
    type: "client_associate"
  , (err, res, body) ->
    cl = undefined
    if err
      cb err, null
    else
      try
        cl = JSON.parse(body)
        cb null, cl
      catch err
        cb err, null


authorize = (cl, rt, user, hostname, port, cb) ->
  unless port
    cb = hostname
    hostname = "localhost"
    port = 4815
  Step (->
    browser = undefined
    proto = undefined
    browser = new Browser(
      runScripts: false
      waitFor: 60000
    )
    proto = (if (port is 443) then "https" else "http")
    browser.visit proto + "://" + hostname + ":" + port + "/oauth/authorize?oauth_token=" + rt.token, this
  ), ((err, br) ->
    throw err  if err
    unless br.success
      throw new OAuthError(
        statusCode: br.statusCode
        data: br.error or br.text("#error")
      )
    br.fill "username", user.nickname, this
  ), ((err, br) ->
    throw err  if err
    br.fill "password", user.password, this
  ), ((err, br) ->
    throw err  if err
    br.pressButton "#authenticate", this
  ), ((err, br) ->
    throw err  if err
    unless br.success
      throw new OAuthError(
        statusCode: br.statusCode
        data: br.error or br.text("#error")
      )
    br.pressButton "Authorize", this
  ), ((err, br) ->
    verifier = undefined
    throw err  if err
    unless br.success
      throw new OAuthError(
        statusCode: br.statusCode
        data: br.error or br.text("#error")
      )
    verifier = br.text("#verifier")
    this null, verifier
  ), cb

redeemToken = (cl, rt, verifier, hostname, port, cb) ->
  proto = undefined
  oa = undefined
  unless port
    cb = hostname
    hostname = "localhost"
    port = 4815
  Step (->
    proto = (if (port is 443) then "https" else "http")
    oa = new OAuth(proto + "://" + hostname + ":" + port + "/oauth/request_token", proto + "://" + hostname + ":" + port + "/oauth/access_token", cl.client_id, cl.client_secret, "1.0", "oob", "HMAC-SHA1", null, # nonce size; use default
      "User-Agent": "pump.io/0.2.0-alpha.1"
    )
    oa.getOAuthAccessToken rt.token, rt.token_secret, verifier, this
  ), (err, token, secret, res) ->
    pair = undefined
    if err
      if err instanceof Error
        cb err, null
      else
        cb new Error(err.data), null
    else
      pair =
        token: token
        token_secret: secret

      cb null, pair


accessToken = (cl, user, hostname, port, cb) ->
  rt = undefined
  unless port
    cb = hostname
    hostname = "localhost"
    port = 4815
  Step (->
    requestToken cl, hostname, port, this
  ), ((err, res) ->
    throw err  if err
    rt = res
    authorize cl, rt, user, hostname, port, this
  ), ((err, verifier) ->
    throw err  if err
    redeemToken cl, rt, verifier, hostname, port, this
  ), cb

register = (cl, nickname, password, hostname, port, callback) ->
  proto = undefined
  unless port
    callback = hostname
    hostname = "localhost"
    port = 4815
  proto = (if (port is 443) then "https" else "http")
  httputil.postJSON proto + "://" + hostname + ":" + port + "/api/users",
    consumer_key: cl.client_id
    consumer_secret: cl.client_secret
  ,
    nickname: nickname
    password: password
  , (err, body, res) ->
    callback err, body


registerEmail = (cl, nickname, password, email, hostname, port, callback) ->
  proto = undefined
  unless port
    callback = hostname
    hostname = "localhost"
    port = 4815
  proto = (if (port is 443) then "https" else "http")
  httputil.postJSON proto + "://" + hostname + ":" + port + "/api/users",
    consumer_key: cl.client_id
    consumer_secret: cl.client_secret
  ,
    nickname: nickname
    password: password
    email: email
  , (err, body, res) ->
    callback err, body


newCredentials = (nickname, password, hostname, port, cb) ->
  cl = undefined
  user = undefined
  unless port
    cb = hostname
    hostname = "localhost"
    port = 4815
  Step (->
    newClient hostname, port, this
  ), ((err, res) ->
    throw err  if err
    cl = res
    newPair cl, nickname, password, hostname, port, this
  ), (err, res) ->
    if err
      cb err, null
    else
      _.extend res,
        consumer_key: cl.client_id
        consumer_secret: cl.client_secret

      cb err, res


newPair = (cl, nickname, password, hostname, port, cb) ->
  user = undefined
  regd = undefined
  unless port
    cb = hostname
    hostname = "localhost"
    port = 4815
  Step (->
    register cl, nickname, password, hostname, port, this
  ), ((err, res) ->
    throw err  if err
    regd = res
    user =
      nickname: nickname
      password: password

    accessToken cl, user, hostname, port, this
  ), (err, res) ->
    if err
      cb err, null
    else
      _.extend res,
        user: regd

      cb null, res



# Call as setupApp(port, hostname, callback)
# setupApp(hostname, callback)
# setupApp(callback)
setupApp = (port, hostname, callback) ->
  unless hostname
    callback = port
    hostname = "localhost"
    port = 4815
  unless callback
    callback = hostname
    hostname = "localhost"
  port = port or 4815
  hostname = hostname or "localhost"
  config =
    port: port
    hostname: hostname

  setupAppConfig config, callback

setupAppConfig = (config, callback) ->
  prop = undefined
  args = []
  config.port = config.port or 4815
  config.hostname = config.hostname or "localhost"
  for prop of config
    args.push prop + "=" + config[prop]
  child = cp.fork(path.join(__dirname, "app.js"), args)
  dummy = close: ->
    child.kill()

  child.on "message", (msg) ->
    if msg.cmd is "listening"
      callback null, dummy
    else callback msg.value, null  if msg.cmd is "error"


exports.requestToken = requestToken
exports.newClient = newClient
exports.register = register
exports.registerEmail = registerEmail
exports.newCredentials = newCredentials
exports.newPair = newPair
exports.accessToken = accessToken
exports.authorize = authorize
exports.redeemToken = redeemToken
exports.setupApp = setupApp
exports.setupAppConfig = setupAppConfig
