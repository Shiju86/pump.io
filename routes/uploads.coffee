# routes/uploads.js
#
# For the /uploads/* endpoints
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
path = require("path")
Step = require("step")
_ = require("underscore")
Activity = require("../lib/model/activity").Activity
HTTPError = require("../lib/httperror").HTTPError
mm = require("../lib/mimemap")
mw = require("../lib/middleware")
sa = require("../lib/sessionauth")
typeToClass = mm.typeToClass
typeToExt = mm.typeToExt
extToType = mm.extToType
hasOAuth = mw.hasOAuth
clientAuth = mw.clientAuth
principal = sa.principal
addRoutes = (app) ->
  if app.session
    app.get "/uploads/*", app.session, everyAuth, uploadedFile
  else
    app.get "/uploads/*", everyAuth, uploadedFile


# XXX: Add remoteUserAuth
everyAuth = (req, res, next) ->
  if hasOAuth(req)
    clientAuth req, res, next
  else if req.session
    principal req, res, next
  else
    next()


# Check downloads of uploaded files
uploadedFile = (req, res, next) ->
  slug = req.params[0]
  ext = slug.match(/\.(.*)$/)[1]
  type = extToType(ext)
  Cls = typeToClass(type)
  profile = (if (req.remoteUser) then req.remoteUser.profile else ((if (req.principal) then req.principal else null)))
  obj = undefined
  req.log.info
    profile: profile
    slug: slug
  , "Checking permissions"
  Step (->
    Cls.search
      _slug: slug
    , this
  ), ((err, objs) ->
    throw err  if err
    throw new Error("Bad number of records for uploads")  if not objs or objs.length isnt 1
    obj = objs[0]
    if profile and obj.author and profile.id is obj.author.id
      res.sendfile path.join(req.app.config.uploaddir, slug)
      return
    Activity.postOf obj, this
  ), ((err, post) ->
    throw err  if err
    throw new HTTPError("Not allowed", 403)  unless post
    post.checkRecipient profile, this
  ), (err, flag) ->
    if err
      next err
    else unless flag
      next new HTTPError("Not allowed", 403)
    else
      res.sendfile path.join(req.app.config.uploaddir, slug)


exports.addRoutes = addRoutes
