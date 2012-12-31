# test utilities for XRD and JRD
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
assert = require("assert")
urlparse = require("url").parse
xml2js = require("xml2js")
vows = require("vows")
Step = require("step")
_ = require("underscore")
http = require("http")
https = require("https")
getXRD = (url) ->
  parts = urlparse(url)
  mod = (if (parts.protocol is "https:") then https else http)
  ->
    callback = @callback
    req = undefined
    req = mod.get(parts, (res) ->
      body = ""
      if res.statusCode isnt 200
        callback new Error("Bad status code (" + res.statusCode + ")"), null, null
      else
        res.setEncoding "utf8"
        res.on "data", (chunk) ->
          body = body + chunk

        res.on "error", (err) ->
          callback err, null, null

        res.on "end", ->
          parser = new xml2js.Parser()
          parser.parseString body, (err, doc) ->
            if err
              callback err, null, null
            else
              callback null, doc, res


    )
    req.on "error", (err) ->
      callback err, null, null


typeCheck = (type) ->
  (err, doc, res) ->
    assert.ifError err
    assert.include res, "headers"
    assert.include res.headers, "content-type"
    assert.equal res.headers["content-type"], type

xrdLinkCheck = (def) ->
  (err, doc, res) ->
    i = undefined
    prop = undefined
    link = undefined
    testLink = (obj) ->
      assert.isObject obj
      assert.include obj, "@"
      assert.isObject obj["@"]
      for prop of def.links[i]
        if def.links[i].hasOwnProperty(prop)
          assert.include obj["@"], prop
          if _.isRegExp(def.links[i][prop])
            assert.match obj["@"][prop], def.links[i][prop]
          else
            assert.equal obj["@"][prop], def.links[i][prop]

    assert.ifError err
    assert.isObject doc
    assert.include doc, "Link"
    if def.links.length is 1
      testLink doc.Link
    else
      assert.isArray doc.Link
      assert.lengthOf doc.Link, def.links.length
      i = 0
      while i < def.links.length
        testLink doc.Link[i]
        i++

xrdContext = (url, def) ->
  ctx =
    topic: getXRD(url)
    "it works": (err, doc, res) ->
      assert.ifError err
      assert.isObject doc
      assert.isObject res

    "it has an XRD content type": typeCheck("application/xrd+xml")

  ctx["it has the correct links"] = xrdLinkCheck(def)  if _(def).has("links")
  ctx

getJRD = (url) ->
  parts = urlparse(url)
  mod = (if (parts.protocol is "https:") then https else http)
  ->
    callback = @callback
    req = undefined
    req = mod.get(parts, (res) ->
      body = ""
      if res.statusCode isnt 200
        callback new Error("Bad status code (" + res.statusCode + ")"), null, null
      else
        res.setEncoding "utf8"
        res.on "data", (chunk) ->
          body = body + chunk

        res.on "error", (err) ->
          callback err, null, null

        res.on "end", ->
          doc = undefined
          try
            doc = JSON.parse(body)
            callback null, doc, res
          catch err
            callback err, null, null

    )
    req.on "error", (err) ->
      callback err, null, null


jrdLinkCheck = (def) ->
  (err, doc, res) ->
    i = undefined
    prop = undefined
    link = undefined
    assert.ifError err
    assert.isObject doc
    assert.include doc, "links"
    assert.isArray doc.links
    assert.lengthOf doc.links, def.links.length
    i = 0
    while i < def.links.length
      assert.isObject doc.links[i]
      for prop of def.links[i]
        if def.links[i].hasOwnProperty(prop)
          assert.include doc.links[i], prop
          if _.isRegExp(def.links[i][prop])
            assert.match doc.links[i][prop], def.links[i][prop]
          else
            assert.equal doc.links[i][prop], def.links[i][prop]
      i++

jrdContext = (url, def) ->
  ctx =
    topic: getJRD(url)
    "it works": (err, doc, res) ->
      assert.ifError err
      assert.isObject doc
      assert.isObject res

    "it has an JRD content type": typeCheck("application/json; charset=utf-8")

  ctx["it has the correct links"] = jrdLinkCheck(def)  if _(def).has("links")
  ctx

module.exports =
  getXRD: getXRD
  getJRD: getJRD
  xrdContext: xrdContext
  jrdContext: jrdContext
  typeCheck: typeCheck
  xrdLinkCheck: xrdLinkCheck
  jrdLinkCheck: jrdLinkCheck
