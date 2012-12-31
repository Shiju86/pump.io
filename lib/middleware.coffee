# middleware.js
#
# Some things you may need
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
databank = require("databank")
Step = require("step")
_ = require("underscore")
bcrypt = require("bcrypt")
fs = require("fs")
path = require("path")
os = require("os")
randomString = require("./randomstring").randomString
Activity = require("./model/activity").Activity
User = require("./model/user").User
Client = require("./model/client").Client
HTTPError = require("./httperror").HTTPError
NoSuchThingError = databank.NoSuchThingError

# If there is a user in the params, gets that user and
# adds them to the request as req.user
# also adds the user's profile to the request as req.profile
# Note: req.user != req.remoteUser
reqUser = (req, res, next) ->
  user = undefined
  Step (->
    User.get req.params.nickname, this
  ), ((err, results) ->
    if err
      if err.name is "NoSuchThingError"
        throw new HTTPError(err.message, 404)
      else
        throw err
    user = results
    user.sanitize()
    req.user = user
    user.expand this
  ), (err) ->
    if err
      next err
    else
      req.person = user.profile
      next()


sameUser = (req, res, next) ->
  if not req.remoteUser or not req.user or req.remoteUser.nickname isnt req.user.nickname
    next new HTTPError("Not authorized", 401)
  else
    next()

maybeAuth = (req, res, next) ->
  unless hasOAuth(req)
    
    # No client, no user
    next()
  else
    clientAuth req, res, next

hasOAuth = (req) ->
  req and _.has(req, "headers") and _.has(req.headers, "authorization") and req.headers.authorization.match(/^OAuth/)


# Accept either 2-legged or 3-legged OAuth
clientAuth = (req, res, next) ->
  log = req.log
  req.client = null
  res.local "client", null # init to null
  if hasToken(req)
    userAuth req, res, next
    return
  log.info "Checking for 2-legged OAuth credentials"
  req.authenticate ["client"], (error, authenticated) ->
    deetz = undefined
    if error
      log.error error
      next error
      return
    unless authenticated
      log.info "Not authenticated"
      return
    log.info "Authentication succeeded"
    deetz = req.getAuthDetails()
    log.info deetz
    if not deetz or not deetz.user or not deetz.user.id
      log.info "Incorrect auth details."
      return
    Client.get deetz.user.id, (err, client) ->
      if error
        next error
        return
      req.client = client
      res.local "client", req.client
      next()



hasToken = (req) ->
  req and (_(req.headers).has("authorization") and req.headers.authorization.match(/oauth_token/)) or (req.query and req.query.oauth_token) or (req.body and req.headers["content-type"] is "application/x-www-form-urlencoded" and req.body.oauth_token)


# Accept only 3-legged OAuth
# XXX: It would be nice to merge these two functions
userAuth = (req, res, next) ->
  log = req.log
  req.remoteUser = null
  res.local "remoteUser", null # init to null
  req.client = null
  res.local "client", null # init to null
  log.info "Checking for 3-legged OAuth credentials"
  req.authenticate ["user"], (error, authenticated) ->
    deetz = undefined
    if error
      log.error error
      next error
      return
    unless authenticated
      log.info "Authentication failed"
      return
    log.info "Authentication succeeded"
    deetz = req.getAuthDetails()
    log.info deetz
    if not deetz or not deetz.user or not deetz.user.user or not deetz.user.client
      log.info "Incorrect auth details."
      next()
      return
    req.remoteUser = deetz.user.user
    res.local "remoteUser", req.remoteUser
    req.client = deetz.user.client
    res.local "client", req.client
    next()



# Accept only 2-legged OAuth with
remoteUserAuth = (req, res, next) ->
  req.client = null
  res.local "client", null # init to null
  req.remotePerson = null
  res.local "person", null
  req.authenticate ["client"], (error, authenticated) ->
    id = undefined
    if error
      next error
      return
    return  unless authenticated
    id = req.getAuthDetails().user.id
    Step (->
      Client.get id, this
    ), (err, client) ->
      if err
        next err
        return
      unless client
        next new HTTPError("No client", 401)
        return
      unless client.webfinger
        next new HTTPError("OAuth key not associated with a webfinger ID", 401)
        return
      req.client = client
      req.webfinger = client.webfinger
      res.local "client", req.client # init to null
      res.local "person", req.person # init to null
      next()



fileContent = (req, res, next) ->
  if req.headers["content-type"] is "application/json"
    binaryJSONContent req, res, next
  else
    otherFileContent req, res, next

otherFileContent = (req, res, next) ->
  req.uploadMimeType = req.headers["content-type"]
  req.uploadContent = req.body
  next()

binaryJSONContent = (req, res, next) ->
  obj = req.body
  fname = undefined
  data = undefined
  unless _.has(obj, "mimeType")
    next new HTTPError("No mime type", 400)
    return
  req.uploadMimeType = obj.mimeType
  unless _.has(obj, "data")
    next new HTTPError("No data", 400)
    return
  
  # Un-URL-safe the data
  obj.data.replace /\-/g, "+"
  obj.data.replace /_/g, "/"
  if obj.data.length % 3 is 1
    obj.data += "=="
  else obj.data += "="  if obj.data.length % 3 is 2
  try
    data = new Buffer(obj.data, "base64")
  catch err
    next err
    return
  Step (->
    randomString 8, this
  ), ((err, str) ->
    ws = undefined
    throw err  if err
    fname = path.join(os.tmpDir(), str + ".bin")
    ws = fs.createWriteStream(fname)
    ws.on "close", this
    ws.write data
    ws.end()
  ), (err) ->
    if err
      next err
    else
      req.uploadFile = fname
      next()



# Add a generator object to writeable requests
reqGenerator = (req, res, next) ->
  client = req.client
  unless client
    next new HTTPError("No client", 500)
    return
  Step (->
    client.asActivityObject this
  ), ((err, obj) ->
    throw err  if err
    req.generator = obj
    this null
  ), next

exports.reqUser = reqUser
exports.reqGenerator = reqGenerator
exports.sameUser = sameUser
exports.userAuth = userAuth
exports.clientAuth = clientAuth
exports.remoteUserAuth = remoteUserAuth
exports.maybeAuth = maybeAuth
exports.fileContent = fileContent
exports.hasOAuth = hasOAuth
