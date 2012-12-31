# pump/model.js
#
# Backbone models for the pump.io client UI
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
((_, $, Backbone, Pump) ->
  
  # Override backbone sync to use OAuth
  Backbone.sync = (method, model, options) ->
    getValue = (object, prop) ->
      return null  unless object and object[prop]
      (if _.isFunction(object[prop]) then object[prop]() else object[prop])

    methodMap =
      create: "POST"
      update: "PUT"
      delete: "DELETE"
      read: "GET"

    type = methodMap[method]
    
    # Default options, unless specified.
    options = options or {}
    
    # Default JSON-request options.
    params =
      type: type
      dataType: "json"

    
    # Ensure that we have a URL.
    unless options.url
      if type is "POST"
        params.url = getValue(model.collection, "url")
      else
        params.url = getValue(model, "url")
      throw new Error("No URL")  if not params.url or not _.isString(params.url)
    
    # Ensure that we have the appropriate request data.
    if not options.data and model and (method is "create" or method is "update")
      params.contentType = "application/json"
      params.data = JSON.stringify(model.toJSON())
    
    # Don't process data on a non-GET request.
    params.processData = false  if params.type isnt "GET" and not Backbone.emulateJSON
    params = _.extend(params, options)
    Pump.ajax params
    null

  
  # A little bit of model sugar
  # Create Model attributes for our object-y things
  Pump.Model = Backbone.Model.extend(
    activityObjects: []
    activityObjectBags: []
    activityObjectStreams: []
    activityStreams: []
    peopleStreams: []
    people: []
    initialize: ->
      obj = this
      neverNew = -> # XXX: neverNude
        false

      initer = (obj, model) ->
        (name) ->
          raw = obj.get(name)
          if raw
            
            # use unique for cached stuff
            if model.unique
              obj[name] = model.unique(raw)
            else
              obj[name] = new model(raw)
            obj[name].isNew = neverNew
          obj.on "change:" + name, (changed) ->
            raw = obj.get(name)
            if obj[name] and obj[name].set
              obj[name].set raw
            else if raw
              if model.unique
                obj[name] = model.unique(raw)
              else
                obj[name] = new model(raw)
              obj[name].isNew = neverNew


      _.each obj.activityObjects, initer(obj, Pump.ActivityObject)
      _.each obj.activityObjectBags, initer(obj, Pump.ActivityObjectBag)
      _.each obj.activityObjectStreams, initer(obj, Pump.ActivityObjectStream)
      _.each obj.activityStreams, initer(obj, Pump.ActivityStream)
      _.each obj.peopleStreams, initer(obj, Pump.PeopleStream)
      _.each obj.people, initer(obj, Pump.Person)

    toJSON: (seen) ->
      obj = this
      id = obj.get(obj.idAttribute)
      json = _.clone(obj.attributes)
      jsoner = (name) ->
        json[name] = obj[name].toJSON(seenNow)  if _.has(obj, name)

      seenNow = undefined
      if seen and id and _.contains(seen, id)
        json =
          id: obj.id
          objectType: obj.get("objectType")
      else
        if seen
          seenNow = seen.slice(0)
        else
          seenNow = []
        seenNow.push id  if id
        _.each obj.activityObjects, jsoner
        _.each obj.activityObjectBags, jsoner
        _.each obj.activityObjectStreams, jsoner
        _.each obj.activityStreams, jsoner
        _.each obj.peopleStreams, jsoner
        _.each obj.people, jsoner
      json

    merge: (props) ->
      model = this
      complicated = model.complicated()
      _.each props, (value, key) ->
        unless model.has(key)
          model.set key, value
        else if _.contains(complicated, key)
          model[key].merge value
        else


    
    # XXX: resolve non-complicated stuff
    complicated: ->
      attrs = ["activityObjects", "activityObjectBags", "activityObjectStreams", "activityStreams", "peopleStreams", "people"]
      names = []
      model = this
      _.each attrs, (attr) ->
        names = names.concat(model[attr])  if _.isArray(model[attr])

      names
  ,
    cache: {}
    keyAttr: "id" # works for activities and activityobjects
    unique: (props) ->
      inst = undefined
      cls = this
      key = props[cls.keyAttr]
      cached = undefined
      if key and _.has(cls.cache, key)
        cached = cls.cache[key]
        
        # Check the updated flag
        if _.has(props, "updated") and cached.has("updated")
          
          # Latest received, so maybe the most recent...?
          cached.merge props
        else
          
          # Latest received, so maybe the most recent...?
          cached.merge props
      inst = new cls(props)
      cls.cache[key] = inst  if key
      inst.on "change:" + cls.keyAttr, (model, key) ->
        oldKey = model.previous(cls.keyAttr)
        delete cls.cache[oldKey]  if oldKey and _.has(cls.cache, oldKey)
        cls.cache[key] = inst

      inst

    clearCache: ->
      @cache = {}
  )
  
  # Our own collection. It's a little screwy; there are
  # a few ways to represent a collection in ActivityStreams JSON and
  # the "infinite stream" thing throws things off a bit too.
  Pump.Collection = Backbone.Collection.extend(
    constructor: (models, options) ->
      coll = this
      
      # If we're being initialized with a JSON Collection, parse it.
      models = coll.parse(models)  if _.isObject(models) and not _.isArray(models)
      if _.isObject(options) and _.has(options, "url")
        coll.url = options.url
        delete options.url
      
      # Use unique() to get unique items
      models = _.map(models, (raw) ->
        coll.model.unique raw
      )
      Backbone.Collection.apply this, [models, options]

    parse: (response) ->
      @url = response.url  if _.has(response, "url")
      @totalItems = response.totalItems  if _.has(response, "totalItems")
      if _.has(response, "links")
        @nextLink = response.links.next.href  if _.has(response.links, "next")
        @prevLink = response.links.prev.href  if _.has(response.links, "prev")
      if _.has(response, "items")
        response.items
      else
        []

    toJSON: (seen) ->
      coll = this
      seenNow = undefined
      items = undefined
      unless seen # Top-level; return as array
        seenNow = [coll.url]
        items = coll.models.map((item) ->
          item.toJSON seenNow
        )
        items
      else if _.contains(seen, coll.url)
        
        # Already seen; return as reference
        url: coll.url
        totalItems: coll.totalItems
      else
        seenNow = seen.slice(0)
        seenNow.push coll.url
        items = coll.models.slice(0, 4).map((item) ->
          item.toJSON seenNow
        )
        url: coll.url
        totalItems: coll.totalItems
        items: items

    merge: (models, options) ->
      coll = this
      mapped = undefined
      props = {}
      if _.isArray(models)
        props.items = models
        props = _.extend(props, options)  if _.isObject(options)
      else props = _.extend(models, options)  if _.isObject(models) and not _.isArray(models)
      coll.url = props.url  if _.has(props, "url") and not _.has(coll, "url")
      coll.totalItems = props.totalItems  if _.has(props, "totalItems") and not _.has(coll, "totalItems")
      if _.has(props, "links")
        coll.nextLink = props.links.next.href  if _.has(props.links, "next") and not _.has(coll, "nextLink")
        coll.prevLink = props.links.prev.href  if _.has(props.links, "prev") and not _.has(coll, "prevLink")
        coll.url = props.links.self.href  if _.has(props.links, "self") and not _.has(coll, "url")
      if _.has(props, "items")
        mapped = props.items.map((item) ->
          coll.model.unique item
        )
        coll.add mapped

    getPrev: -> # Get stuff later than the current group
      coll = this
      options = undefined
      throw new Error("No prevLink.")  unless coll.prevLink
      options =
        type: "GET"
        dataType: "json"
        url: coll.prevLink
        success: (data) ->
          if data.items
            coll.add data.items,
              at: 0

          coll.prevLink = data.links.prev.href  if data.links and data.links.prev and data.links.prev.href

        error: (jqxhr) ->
          Pump.error "Failed getting more items."

      Pump.ajax options

    getNext: -> # Get stuff later than the current group
      coll = this
      options = undefined
      
      # No next link
      return  unless coll.nextLink
      options =
        type: "GET"
        dataType: "json"
        url: coll.nextLink
        success: (data) ->
          if data.items
            coll.add data.items,
              at: coll.length

          if data.links and data.links.next and data.links.next.href
            coll.nextLink = data.links.next.href
          else
            
            # XXX: end-of-collection indicator?
            delete coll.nextLink

        error: (jqxhr) ->
          Pump.error "Failed getting more items."

      Pump.ajax options
  ,
    cache: {}
    keyAttr: "url" # works for in-model collections
    unique: (models, options) ->
      inst = undefined
      cls = this
      key = undefined
      cached = undefined
      
      # If we're being initialized with a JSON Collection, parse it.
      if _.isObject(models) and not _.isArray(models)
        key = models[cls.keyAttr]
      else key = options[cls.keyAttr]  if _.isObject(options) and _.has(options, cls.keyAttr)
      if key and _.has(cls.cache, key)
        cached = cls.cache[key]
        cached.merge models, options
      inst = new cls(models, options)
      cls.cache[key] = inst  if key
      inst.on "change:" + cls.keyAttr, (model, key) ->
        oldKey = model.previous(cls.keyAttr)
        delete cls.cache[oldKey]  if oldKey and _.has(cls.cache, oldKey)
        cls.cache[key] = inst

      inst

    clearCache: ->
      @cache = {}
  )
  
  # A social activity.
  Pump.Activity = Pump.Model.extend(
    activityObjects: ["actor", "object", "target", "generator", "provider", "location"]
    activityObjectBags: ["to", "cc", "bto", "bcc"]
    url: ->
      links = @get("links")
      uuid = @get("uuid")
      if links and _.isObject(links) and links.self
        links.self
      else if uuid
        "/api/activity/" + uuid
      else
        null
  )
  Pump.ActivityStream = Pump.Collection.extend(
    model: Pump.Activity
    add: (models, options) ->
      
      # Usually add at the beginning of the list
      options = {}  unless options
      options.at = 0  unless _.has(options, "at")
      Backbone.Collection::add.apply this, [models, options]
  )
  Pump.ActivityObject = Pump.Model.extend(
    activityObjects: ["author", "location", "inReplyTo"]
    activityObjectBags: ["attachments", "tags"]
    activityObjectStreams: ["likes", "replies", "shares"]
    url: ->
      links = @get("links")
      uuid = @get("uuid")
      objectType = @get("objectType")
      if links and _.isObject(links) and _.has(links, "self") and _.isObject(links.self) and _.has(links.self, "href") and _.isString(links.self.href)
        links.self.href
      else if objectType
        "/api/" + objectType + "/" + uuid
      else
        null
  )
  Pump.Person = Pump.ActivityObject.extend(
    objectType: "person"
    activityObjectStreams: ["favorites", "lists"]
    peopleStreams: ["followers", "following"]
    initialize: ->
      Pump.Model::initialize.apply this, arguments_
  )
  Pump.ActivityObjectStream = Pump.Collection.extend(model: Pump.ActivityObject)
  
  # Unordered, doesn't have an URL
  Pump.ActivityObjectBag = Backbone.Collection.extend(model: Pump.ActivityObject)
  Pump.PeopleStream = Pump.ActivityObjectStream.extend(model: Pump.Person)
  Pump.User = Pump.Model.extend(
    idAttribute: "nickname"
    people: ["profile"]
    initialize: ->
      user = this
      streamUrl = (rel) ->
        "/api/user/" + user.get("nickname") + rel

      userStream = (rel) ->
        Pump.ActivityStream.unique [],
          url: streamUrl(rel)


      Pump.Model::initialize.apply this, arguments_
      
      # XXX: maybe move some of these to Person...?
      user.inbox = userStream("/inbox")
      user.majorInbox = userStream("/inbox/major")
      user.minorInbox = userStream("/inbox/minor")
      user.directInbox = userStream("/inbox/direct")
      user.majorDirectInbox = userStream("/inbox/direct/major")
      user.minorDirectInbox = userStream("/inbox/direct/minor")
      user.stream = userStream("/feed")
      user.majorStream = userStream("/feed/major")
      user.minorStream = userStream("/feed/minor")
      user.on "change:nickname", ->
        user.inbox.url = streamUrl("/inbox")
        user.majorInbox.url = streamUrl("/inbox/major")
        user.minorInbox.url = streamUrl("/inbox/minor")
        user.directInbox.url = streamUrl("/inbox/direct")
        user.majorDirectInbox.url = streamUrl("/inbox/direct/major")
        user.minorDirectInbox.url = streamUrl("/inbox/direct/minor")
        user.stream.url = streamUrl("/feed")
        user.majorStream.url = streamUrl("/feed/major")
        user.minorStream.url = streamUrl("/feed/minor")


    isNew: ->
      
      # Always PUT
      false

    url: ->
      "/api/user/" + @get("nickname")
  ,
    cache: {} # separate cache
    keyAttr: "nickname" # cache by nickname
    clearCache: ->
      @cache = {}
  )
) window._, window.$, window.Backbone, window.Pump
