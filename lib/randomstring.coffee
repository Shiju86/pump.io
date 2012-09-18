# Random string
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
crypto = require("crypto")
randomString = (bytes, callback) ->
  crypto.randomBytes bytes, (err, buf) ->
    str = undefined
    if err
      callback err, null
    else
      str = buf.toString("base64")
      
      # XXX: optimize me
      
      # XXX: optimize me
      str = str.replace(/\+/g, "-")
      str = str.replace(/\//g, "_")
      str = str.replace(RegExp("=", "g"), "")
      callback null, str


exports.randomString = randomString
