# model.js
#
# Test utility for databankobject model modules
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
assert = require("assert")
vows = require("vows")
databank = require("databank")
Step = require("step")
fs = require("fs")
path = require("path")
URLMaker = require("../../lib/urlmaker").URLMaker
schema = require("../../lib/schema").schema
Databank = databank.Databank
DatabankObject = databank.DatabankObject
tc = JSON.parse(fs.readFileSync(path.resolve(__dirname, "..", "config.json")))
modelBatch = (typeName, className, testSchema, testData) ->
  batch = {}
  typeKey = "When we require the " + typeName + " module"
  classKey = "and we get its " + className + " class export"
  instKey = undefined
  if "aeiouAEIOU".indexOf(typeName.charAt(0)) isnt -1
    instKey = "and we create an " + typeName + " instance"
  else
    instKey = "and we create a " + typeName + " instance"
  batch[typeKey] =
    topic: ->
      cb = @callback
      
      # Need this to make IDs
      URLMaker.hostname = "example.net"
      
      # Dummy databank
      tc.params.schema = schema
      db = Databank.get(tc.driver, tc.params)
      db.connect {}, (err) ->
        mod = undefined
        DatabankObject.bank = db
        mod = require("../../lib/model/" + typeName) or null
        cb null, mod


    "there is one": (err, mod) ->
      assert.isObject mod

    "it has a class export": (err, mod) ->
      assert.includes mod, className

  batch[typeKey][classKey] =
    topic: (mod) ->
      mod[className] or null

    "it is a function": (Cls) ->
      assert.isFunction Cls

    "it has an init method": (Cls) ->
      assert.isFunction Cls.init

    "it has a bank method": (Cls) ->
      assert.isFunction Cls.bank

    "it has a get method": (Cls) ->
      assert.isFunction Cls.get

    "it has a search method": (Cls) ->
      assert.isFunction Cls.search

    "it has a pkey method": (Cls) ->
      assert.isFunction Cls.pkey

    "it has a create method": (Cls) ->
      assert.isFunction Cls.create

    "it has a readAll method": (Cls) ->
      assert.isFunction Cls.readAll

    "its type is correct": (Cls) ->
      assert.isString Cls.type
      assert.equal Cls.type, typeName

    "and we get its schema":
      topic: (Cls) ->
        Cls.schema or null

      "it exists": (schema) ->
        assert.isObject schema

      "it has the right pkey": (schema) ->
        assert.includes schema, "pkey"
        assert.equal schema.pkey, testSchema.pkey

      "it has the right fields": (schema) ->
        fields = testSchema.fields
        i = undefined
        field = undefined
        if fields
          assert.includes schema, "fields"
          i = 0
          while i < fields.length
            assert.includes schema.fields, fields[i]
            i++
          i = 0
          while i < schema.fields.length
            assert.includes fields, schema.fields[i]
            i++

      "it has the right indices": (schema) ->
        indices = testSchema.indices
        i = undefined
        field = undefined
        if indices
          assert.includes schema, "indices"
          i = 0
          while i < indices.length
            assert.includes schema.indices, indices[i]
            i++
          i = 0
          while i < schema.indices.length
            assert.includes indices, schema.indices[i]
            i++

  batch[typeKey][classKey][instKey] =
    topic: (Cls) ->
      Cls.create testData.create, @callback

    "it works correctly": (err, created) ->
      assert.ifError err
      assert.isObject created

    "auto-generated fields are there": (err, created) ->
      assert.isString created.objectType
      assert.equal created.objectType, typeName
      assert.isString created.id
      assert.isString created.published
      assert.isString created.updated # required for new object?

    "passed-in fields are there": (err, created) ->
      prop = undefined
      aprop = undefined
      for prop of testData.create
        
        # Author may have auto-created properties
        if prop is "author"
          for aprop of testData.create.author
            assert.deepEqual created.author[aprop], testData.create.author[aprop]
        else
          assert.deepEqual created[prop], testData.create[prop]

    "and we modify it":
      topic: (created) ->
        created.update testData.update, @callback

      "it is modified": (err, updated) ->
        assert.ifError err
        assert.isString updated.updated

      "modified fields are modified": (err, updated) ->
        prop = undefined
        for prop of testData.update
          assert.deepEqual updated[prop], testData.update[prop]

      "and we delete it":
        topic: (updated) ->
          updated.del @callback

        "it works": (err, updated) ->
          assert.ifError err

  batch

exports.modelBatch = modelBatch
