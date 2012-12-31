# lib/saveupload.js
#
# The necessary recipe for saving uploaded files
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
Step = require("step")
path = require("path")
fs = require("fs")
mkdirp = require("mkdirp")
_ = require("underscore")
HTTPError = require("../lib/httperror").HTTPError
ActivityObject = require("../lib/model/activityobject").ActivityObject
URLMaker = require("../lib/urlmaker").URLMaker
randomString = require("../lib/randomstring").randomString
mm = require("../lib/mimemap")
typeToClass = mm.typeToClass
typeToExt = mm.typeToExt
extToType = mm.extToType
slowMove = (oldName, newName, callback) ->
  rs = undefined
  ws = undefined
  onClose = ->
    clear()
    callback null

  onError = (err) ->
    clear()
    callback err

  clear = ->
    rs.removeListener "error", onError
    ws.removeListener "error", onError
    ws.removeListener "close", onClose

  try
    rs = fs.createReadStream(oldName)
    ws = fs.createWriteStream(newName)
  catch err
    callback err
    return
  ws.on "close", onClose
  rs.on "error", onError
  ws.on "error", onError
  rs.pipe ws

saveUpload = (user, mimeType, fileName, uploadDir, params, callback) ->
  props = undefined
  now = new Date()
  ext = typeToExt(mimeType)
  dir = path.join(user.nickname, "" + now.getUTCFullYear(), "" + (now.getUTCMonth() + 1), "" + now.getUTCDate())
  fulldir = path.join(uploadDir, dir)
  slug = undefined
  obj = undefined
  fname = undefined
  
  # params are optional
  unless callback
    callback = params
    params = {}
  Step (->
    mkdirp fulldir, this
  ), ((err) ->
    throw err  if err
    randomString 4, this
  ), ((err, rnd) ->
    throw err  if err
    slug = path.join(dir, rnd + "." + ext)
    fname = path.join(uploadDir, slug)

    fs.rename fileName, fname, this
  ), ((err) ->
    if err
      if err.code is "EXDEV"
        slowMove fileName, fname, this
      else
        throw err
    else
      this null
  ), ((err) ->
    Cls = undefined
    url = undefined
    throw err  if err
    url = URLMaker.makeURL("uploads/" + slug)
    Cls = typeToClass(mimeType)
    switch Cls.type
      when ActivityObject.IMAGE
        props =
          _slug: slug
          author: user.profile
          image:
            url: url

          fullImage:
            url: url
      when ActivityObject.AUDIO, ActivityObject.VIDEO
        props =
          _slug: slug
          author: user.profile
          stream:
            url: url
      when ActivityObject.FILE
        props =
          _slug: slug
          author: user.profile
          fileUrl: url
          mimeType: mimeType
      else
        throw new Error("Unknown type.")
    
    # XXX: summary, or content?
    props.content = params.description  if _.has(params, "description")
    props.displayName = params.title  if _.has(params, "title")
    Cls.create props, this
  ), ((err, result) ->
    throw err  if err
    obj = result
    user.uploadsStream this
  ), ((err, str) ->
    throw err  if err
    str.deliverObject
      id: obj.id
      objectType: obj.objectType
    , this
  ), (err) ->
    if err
      callback err, null
    else
      callback null, obj


exports.saveUpload = saveUpload
