# sessionauth.js
#
# Authenticate using sessions
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
_ = require("underscore")
ActivityObject = require("./model/activityobject").ActivityObject
User = require("./model/user").User
HTTPError = require("./httperror").HTTPError
setPrincipal = (session, obj, callback) ->
  ref =
    id: obj.id
    objectType: obj.objectType

  session.principal = ref
  callback null

getPrincipal = (session, callback) ->
  if not session or not _.has(session, "principal")
    callback null, null
    return
  ref = session.principal
  Step (->
    ActivityObject.getObject ref.objectType, ref.id, this
  ), callback

clearPrincipal = (session, callback) ->
  if not session or not _.has(session, "principal")
    callback null
    return
  delete session.principal

  callback null

principal = (req, res, next) ->
  req.log.info
    msg: "Checking for principal"
    session: req.session

  Step (->
    getPrincipal req.session, this
  ), ((err, principal) ->
    throw err  if err
    if principal
      req.log.info
        msg: "Setting session principal"
        principal: principal

      req.principal = principal
      User.fromPerson principal.id, this
    else
      req.principal = null
      req.principalUser = null
      next()
  ), (err, user) ->
    if err
      next err
    else
      
      # XXX: null on miss
      if user
        req.log.info
          msg: "Setting session principal user"
          user: user

        req.principalUser = user
      next()


principalUserOnly = (req, res, next) ->
  if not _.has(req, "principalUser") or not req.principalUser
    next new HTTPError("Not logged in.", 401)
  else
    next()

exports.principal = principal
exports.setPrincipal = setPrincipal
exports.getPrincipal = getPrincipal
exports.clearPrincipal = clearPrincipal
exports.principalUserOnly = principalUserOnly
