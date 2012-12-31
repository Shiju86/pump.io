# scrubber.js
#
# Scrub HTML for dangerous XSS crap
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
validator = require("validator")
_ = require("underscore")
check = validator.check
sanitize = validator.sanitize
Scrubber =
  scrub: (str) ->
    sanitize(str).xss()

  scrubActivity: (act) ->
    strings = ["content"]
    objects = ["actor", "object", "target", "generator", "provider", "context", "source"]
    arrays = ["to", "cc", "bto", "bcc"]
    
    # Remove any incoming private properties
    _.each act, (value, key) ->
      delete act[key]  if key[0] is "_"

    _.each strings, (sprop) ->
      act[sprop] = Scrubber.scrub(act[sprop])  if _.has(act, sprop)

    _.each objects, (prop) ->
      act[prop] = Scrubber.scrubObject(act[prop])  if _.isObject(act[prop])  if _.has(act, prop)

    _.each arrays, (array) ->
      if _.has(act, array)
        if _.isArray(act[array])
          _.each act[array], (item, index) ->
            Scrubber.scrubObject item


    act

  scrubObject: (obj) ->
    strings = ["content", "summary"]
    objects = ["author", "location"]
    arrays = ["attachments", "tags"]
    
    # Remove any incoming private properties
    _.each obj, (value, key) ->
      delete obj[key]  if key[0] is "_"

    _.each strings, (sprop) ->
      obj[sprop] = Scrubber.scrub(obj[sprop])  if _.has(obj, sprop)

    _.each objects, (prop) ->
      obj[prop] = Scrubber.scrubObject(obj[prop])  if _.isObject(obj[prop])  if _.has(obj, prop)

    _.each arrays, (array) ->
      if _.has(obj, array)
        if _.isArray(obj[array])
          _.each obj[array], (item, index) ->
            Scrubber.scrubObject item


    obj


# So you can require("scrubber").Scrubber or just require("scrubber")
Scrubber.Scrubber = Scrubber
module.exports = Scrubber
