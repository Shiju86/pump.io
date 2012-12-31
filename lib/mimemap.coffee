# lib/mimemap.js
#
# map mime types to extensions or classes
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
_ = require("underscore")
File = require("./model/file").File
Image = require("./model/image").Image
Audio = require("./model/audio").Audio
Video = require("./model/video").Video
type2ext =
  "audio/flac": "flac"
  "audio/mpeg": "mp3"
  "audio/ogg": "ogg"
  "audio/x-wav": "wav"
  "image/gif": "gif"
  "image/jpeg": "jpg"
  "image/png": "png"
  "image/svg+xml": "svg"
  "video/3gpp": "3gp"
  "video/mpeg": "mpg"
  "video/mp4": "mp4"
  "video/quicktime": "mov"
  "video/ogg": "ogv"
  "video/webm": "webm"
  "video/x-msvideo": "avi"

ext2type = _.invert(type2ext)
typeToClass = (type) ->
  unless type
    File
  else if type.match(/^image\//)
    Image
  else if type.match(/^audio\//)
    Audio
  else if type.match(/^video\//)
    Video
  else
    File

typeToExt = (type) ->
  (if _.has(type2ext, type) then type2ext[type] else "bin")

extToType = (ext) ->
  (if (_.has(ext2type, ext)) then ext2type[ext] else null)

exports.typeToExt = typeToExt
exports.extToType = extToType
exports.typeToClass = typeToClass
