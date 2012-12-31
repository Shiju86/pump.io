# activity.js
#
# data object representing an activity
#
# Copyright 2011,2012 StatusNet Inc.
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
URLMaker = require("../urlmaker").URLMaker
IDMaker = require("../idmaker").IDMaker
Stamper = require("../stamper").Stamper
ActivityObject = require("./activityobject").ActivityObject
Edge = require("./edge").Edge
Share = require("./share").Share
Favorite = require("./favorite").Favorite
DatabankObject = databank.DatabankObject
NoSuchThingError = databank.NoSuchThingError
NotInStreamError = require("./stream").NotInStreamError
AppError = (msg) ->
  Error.captureStackTrace this, AppError
  @name = "AppError"
  @message = msg

AppError:: = new Error()
AppError::constructor = AppError
Activity = DatabankObject.subClass("activity")
Activity.schema =
  pkey: "id"
  fields: ["actor", "content", "generator", "icon", "id", "object", "published", "provider", "target", "title", "url", "_uuid", "updated", "verb"]
  indices: ["actor.id", "object.id", "_uuid"]

Activity.init = (inst, properties) ->
  props = ["to", "cc", "bto", "bcc"]
  i = undefined
  j = undefined
  addrs = undefined
  DatabankObject.init inst, properties
  @verb = "post"  unless @verb
  inst.actor = ActivityObject.toObject(inst.actor, ActivityObject.PERSON)  if inst.actor
  inst.object = ActivityObject.toObject(inst.object)  if inst.object
  i = 0
  while i < props.length
    addrs = this[props[i]]
    if addrs and _.isArray(addrs)
      j = 0
      while j < addrs.length
        addrs[j] = ActivityObject.toObject(addrs[j], ActivityObject.PERSON)  if _.isObject(addrs[j])
        j++
    i++

Activity::apply = (defaultActor, callback) ->
  act = this
  verb = undefined
  method = undefined
  camelCase = (str) ->
    parts = str.split("-")
    upcase = parts.map((part) ->
      part.substring(0, 1).toUpperCase() + part.substring(1, part.length).toLowerCase()
    )
    upcase.join ""

  
  # Ensure an actor
  act.actor = act.actor or defaultActor
  
  # Find the apply method
  verb = act.verb
  
  # On unknown verb, skip
  unless _.contains(Activity.verbs, verb)
    callback null
    return
  
  # Method like applyLike or applyStopFollowing
  method = "apply" + camelCase(verb)
  
  # Do we know how to apply it?
  unless _.isFunction(act[method])
    callback null
    return
  act[method] callback

Activity::applyPost = (callback) ->
  act = this
  
  # Force author data
  @object.author = @actor
  
  # Is this it...?
  Step (->
    ActivityObject.getObject act.object.objectType, act.object.id, this
  ), ((err, obj) ->
    if err
      if err.name is "NoSuchThingError"
        ActivityObject.createObject act.object, callback
        return
      else
        throw err
    Activity.postOf obj, this
  ), (err, post) ->
    throw err  if err
    if post
      callback new Error("Already posted"), null
    else
      callback null, act.object


Activity::applyCreate = Activity::applyPost
Activity::applyFollow = (callback) ->
  act = this
  User = require("./user").User
  user = undefined
  if not @actor.id or not @object.id
    callback new AppError("No ID.")
    return
  Step (->
    Edge.create
      from: act.actor
      to: act.object
    , this
  ), ((err, edge) ->
    throw err  if err
    ActivityObject.ensureObject act.actor, @parallel()
    ActivityObject.ensureObject act.object, @parallel()
  ), ((err, follower, followed) ->
    throw err  if err
    User.fromPerson follower.id, @parallel()
    User.fromPerson followed.id, @parallel()
  ), ((err, followerUser, followedUser) ->
    group = @group()
    throw err  if err
    followerUser.addFollowing act.object.id, group()  if followerUser
    followedUser.addFollower act.actor.id, group()  if followedUser
  ), (err) ->
    if err
      callback err
    else
      callback null


Activity::applyStopFollowing = (callback) ->
  act = this
  User = require("./user").User
  user = undefined
  
  # XXX: OStatus if necessary
  if not @actor.id or not @object.id
    callback new AppError("No ID.")
    return
  Step (->
    Edge.get Edge.id(act.actor.id, act.object.id), this
  ), ((err, edge) ->
    throw err  if err
    edge.del this
  ), ((err) ->
    throw err  if err
    ActivityObject.ensureObject act.actor, @parallel()
    ActivityObject.ensureObject act.object, @parallel()
  ), ((err, follower, followed) ->
    throw err  if err
    User.fromPerson follower.id, @parallel()
    User.fromPerson followed.id, @parallel()
  ), ((err, followerUser, followedUser) ->
    group = @group()
    throw err  if err
    followerUser.removeFollowing act.object.id, group()  if followerUser
    followedUser.removeFollower act.actor.id, group()  if followedUser
  ), (err) ->
    if err
      callback err
    else
      callback null


Activity::applyFavorite = (callback) ->
  act = this
  User = require("./user").User
  Step (->
    Favorite.create
      from: act.actor
      to: act.object
    , this
  ), ((err, fave) ->
    throw err  if err
    ActivityObject.ensureObject act.object, this
  ), ((err, object) ->
    throw err  if err
    object.favoritedBy act.actor.id, this
  ), ((err) ->
    throw err  if err
    User.fromPerson act.actor.id, this
  ), ((err, user) ->
    throw err  if err
    if user
      user.addToFavorites act.object, this
    else
      this null
  ), callback

Activity::applyLike = Activity::applyFavorite
Activity::applyUnfavorite = (callback) ->
  act = this
  User = require("./user").User
  Step (->
    Favorite.get Favorite.id(act.actor.id, act.object.id), this
  ), ((err, favorite) ->
    throw err  if err
    favorite.del this
  ), ((err) ->
    throw err  if err
    ActivityObject.ensureObject act.object, this
  ), ((err, obj) ->
    throw err  if err
    obj.unfavoritedBy act.actor.id, this
  ), ((err) ->
    throw err  if err
    User.fromPerson act.actor.id, this
  ), ((err, user) ->
    throw err  if err
    if user
      user.removeFromFavorites act.object, this
    else
      this null
  ), callback

Activity::applyUnlike = Activity::applyUnfavorite
Activity::applyDelete = (callback) ->
  act = this
  Step (->
    ActivityObject.getObject act.object.objectType, act.object.id, this
  ), ((err, toDelete) ->
    throw err  if err
    throw new AppError("Can't delete " + toDelete.id + ": not author.")  if not _.has(toDelete, "author") or not _.isObject(toDelete.author) or (toDelete.author.id isnt act.actor.id)
    toDelete.efface this
  ), (err, ts) ->
    if err
      callback err
    else
      callback null


Activity::applyUpdate = (callback) ->
  act = this
  Step (->
    ActivityObject.getObject act.object.objectType, act.object.id, this
  ), ((err, toUpdate) ->
    throw err  if err
    if _.has(toUpdate, "author") and _.isObject(toUpdate.author)
      
      # has an author; check if it's the actor
      throw new AppError("Can't update " + toUpdate.id + ": not author.")  if toUpdate.author.id isnt act.actor.id
    else
      
      # has no author; only OK if it's the actor updating their own profile
      throw new AppError("Can't update " + toUpdate.id + ": not you.")  if act.actor.id isnt act.object.id
    toUpdate.update act.object, this
  ), (err, result) ->
    if err
      callback err
    else
      act.object = result
      callback null


Activity::applyAdd = (callback) ->
  act = this
  Step (->
    ActivityObject.ensureObject act.object, @parallel()
    ActivityObject.getObject act.target.objectType, act.target.id, @parallel()
  ), ((err, toAdd, target) ->
    throw err  if err
    throw new AppError("Can't add to " + target.id + ": not author.")  if target.author.id isnt act.actor.id
    throw new AppError("Can't add to " + target.id + ": not a collection.")  if target.objectType isnt "collection"
    throw new AppError("Can't add to " + target.id + ": incorrect type.")  if not _(target).has("objectTypes") or not _(target.objectTypes).isArray() or target.objectTypes.indexOf(toAdd.objectType) is -1
    target.getStream this
  ), ((err, stream) ->
    throw err  if err
    stream.deliverObject
      id: act.object.id
      objectType: act.object.objectType
    , this
  ), (err) ->
    if err
      callback err
    else
      callback null


Activity::applyRemove = (callback) ->
  act = this
  Step (->
    ActivityObject.ensureObject act.object, @parallel()
    ActivityObject.getObject act.target.objectType, act.target.id, @parallel()
  ), ((err, toAdd, target) ->
    throw err  if err
    throw new AppError("Can't remove from " + target.id + ": not author.")  if target.author.id isnt act.actor.id
    throw new AppError("Can't remove from " + target.id + ": not a collection.")  if target.objectType isnt "collection"
    throw new AppError("Can't remove from " + target.id + ": incorrect type.")  if not _(target).has("objectTypes") or not _(target.objectTypes).isArray() or target.objectTypes.indexOf(toAdd.objectType) is -1
    target.getStream this
  ), ((err, stream) ->
    throw err  if err
    stream.removeObject
      id: act.object.id
      objectType: act.object.objectType
    , this
  ), (err) ->
    if err
      callback err
    else
      callback null


Activity::applyShare = (callback) ->
  act = this
  Step (->
    ActivityObject.ensureObject act.object, this
  ), ((err, obj) ->
    throw err  if err
    obj.getSharesStream this
  ), ((err, str) ->
    ref = undefined
    throw err  if err
    ref =
      objectType: act.actor.objectType
      id: act.actor.id

    str.deliverObject ref, this
  ), ((err) ->
    share = undefined
    throw err  if err
    share = new Share(
      sharer: act.actor
      shared: act.object
    )
    share.save this
  ), callback

Activity::applyUnshare = (callback) ->
  act = this
  Step (->
    ActivityObject.ensureObject act.object, this
  ), ((err, obj) ->
    throw err  if err
    obj.getSharesStream this
  ), ((err, str) ->
    ref = undefined
    throw err  if err
    ref =
      objectType: act.actor.objectType
      id: act.actor.id

    str.removeObject ref, this
  ), ((err) ->
    throw err  if err
    Share.get Share.id(act.actor, act.object), this
  ), ((err, share) ->
    throw err  if err
    share.del this
  ), callback

Activity::recipients = ->
  act = this
  props = ["to", "cc", "bto", "bcc"]
  recipients = []
  props.forEach (prop) ->
    recipients = recipients.concat(act[prop])  if _(act).has(prop) and _(act[prop]).isArray()

  
  # XXX: ensure uniqueness
  recipients


# Set default recipients
Activity::ensureRecipients = (callback) ->
  act = this
  recipients = act.recipients()
  
  # If we've got recipients, cool.
  if recipients.length > 0
    callback null
    return
  
  # Modification verbs use same as original post
  # Note: skip update/delete of self; handled below
  if (act.verb is Activity.DELETE or act.verb is Activity.UPDATE) and (not act.actor or not act.object or act.actor.id isnt act.object.id)
    Step (->
      ActivityObject.getObject act.object.objectType, act.object.id, this
    ), ((err, orig) ->
      throw err  if err
      Activity.postOf orig, this
    ), (err, post) ->
      props = ["to", "cc", "bto", "bcc"]
      if err
        callback err
      else unless post
        callback new Error("no original post")
      else
        props.forEach (prop) ->
          act[prop] = post[prop]  if post.hasOwnProperty(prop)

        callback null

  else if act.object and act.object.inReplyTo
    
    # Replies use same as original post
    Step (->
      ActivityObject.ensureObject act.object.inReplyTo, this
    ), ((err, orig) ->
      throw err  if err
      Activity.postOf orig, this
    ), (err, post) ->
      props = ["to", "cc", "bto", "bcc"]
      if err
        callback err
      else unless post
        callback new Error("no original post")
      else
        props.forEach (prop) ->
          if post.hasOwnProperty(prop)
            act[prop] = []
            post[prop].forEach (addr) ->
              act[prop].push addr  if addr.id isnt act.actor.id


        act.to = []  unless act.to
        act.to.push post.actor
        callback null

  else if act.object and act.object.objectType is ActivityObject.PERSON and (not act.actor or act.actor.id isnt act.object.id)
    
    # XXX: cc? bto?
    act.to = [act.object]
    callback null
  else if act.actor and act.actor.objectType is ActivityObject.PERSON
    
    # Default is to user's followers
    Step (->
      ActivityObject.ensureObject act.actor, this
    ), ((err, actor) ->
      throw err  if err
      actor.followersURL this
    ), (err, url) ->
      if err
        callback err
      else unless url
        callback new Error("no followers url")
      else
        act.cc = [
          objectType: "collection"
          id: url
        ]
        callback null

  else
    callback new Error("Can't ensure recipients.")


# XXX: identical to save
Activity.beforeCreate = (props, callback) ->
  now = Stamper.stamp()
  props.updated = now
  props.published = now  unless props.published
  unless props.id
    props._uuid = IDMaker.makeID()
    props.id = ActivityObject.makeURI("activity", props._uuid)
    props.links = {}  unless _(props).has("links")
    props.links.self = href: URLMaker.makeURL("api/activity/" + props._uuid)
    props.url = URLMaker.makeURL(props.actor.preferredUsername + "/activity/" + props._uuid)  if _.has(props, "author") and _.isObject(props.author) and _.has(props.author, "preferredUsername") and _.isString(props.author.preferredUsername)
    
    # default verb
    props.verb = "post"  unless props.verb
  callback new Error("Activity has no actor"), null  unless props.actor
  callback new Error("Activity has no object"), null  unless props.object
  props.content = Activity.makeContent(props)  unless props.content
  Step (->
    ActivityObject.compressProperty props, "actor", @parallel()
    ActivityObject.compressProperty props, "object", @parallel()
    ActivityObject.compressProperty props, "target", @parallel()
    ActivityObject.compressProperty props, "generator", @parallel()
    ActivityObject.compressArray props, "to", @parallel()
    ActivityObject.compressArray props, "cc", @parallel()
    ActivityObject.compressArray props, "bto", @parallel()
    ActivityObject.compressArray props, "bcc", @parallel()
  ), (err) ->
    if err
      callback err, null
    else
      callback null, props



# XXX: i18n, real real bad
Activity.makeContent = (props) ->
  content = undefined
  nameOf = (obj) ->
    if _.has(obj, "displayName")
      obj.displayName
    else if ["a", "e", "i", "o", "u"].indexOf(obj.objectType[0]) isnt -1
      "an " + obj.objectType
    else
      "a " + obj.objectType

  reprOf = (obj) ->
    name = nameOf(obj)
    if _.has(obj, "url")
      "<a href='" + obj.url + "'>" + name + "</a>"
    else
      name

  pastOf = (verb) ->
    last = verb[verb.length - 1]
    irreg =
      at: "was at"
      build: "built"
      checkin: "checked into"
      find: "found"
      give: "gave"
      leave: "left"
      lose: "lost"
      "make-friend": "made a friend of"
      play: "played"
      read: "read"
      "remove-friend": "removed as a friend"
      "rsvp-maybe": "may attend"
      "rsvp-no": "will not attend"
      "rsvp-yes": "will attend"
      sell: "sold"
      send: "sent"
      "stop-following": "stopped following"
      submit: "submitted"
      tag: "tagged"
      win: "won"

    return irreg[verb]  if _.has(irreg, verb)
    switch last
      when "y"
        return verb.substr(0, verb.length - 1) + "ied"
      when "e"
        verb + "d"
      else
        verb + "ed"

  content = reprOf(props.actor) + " " + pastOf(props.verb or "post") + " " + reprOf(props.object)
  content = content + " in reply to " + reprOf(props.object.inReplyTo)  if _.has(props.object, "inReplyTo")
  content = content + " to " + reprOf(props.target)  if _.has(props.object, "target")
  content

Activity::beforeUpdate = (props, callback) ->
  now = Stamper.stamp()
  props.updated = now
  Step (->
    ActivityObject.compressProperty props, "actor", @parallel()
    ActivityObject.compressProperty props, "object", @parallel()
    ActivityObject.compressProperty props, "target", @parallel()
    ActivityObject.compressProperty props, "generator", @parallel()
    ActivityObject.compressArray props, "to", @parallel()
    ActivityObject.compressArray props, "cc", @parallel()
    ActivityObject.compressArray props, "bto", @parallel()
    ActivityObject.compressArray props, "bcc", @parallel()
  ), (err) ->
    if err
      callback err, null
    else
      callback null, props



# When save()'ing an activity, ensure the actor and object
# are persisted, then save them by reference.
Activity::beforeSave = (callback) ->
  now = Stamper.stamp()
  act = this
  act.updated = now
  act.published = now  unless act.published
  unless act.id
    act._uuid = IDMaker.makeID()
    act.id = ActivityObject.makeURI("activity", act._uuid)
    act.links = {}  unless _(act).has("links")
    act.links.self = href: URLMaker.makeURL("api/activity/" + act._uuid)
    
    # FIXME: assumes person data was set and that it's a local actor
    act.url = URLMaker.makeURL(act.actor.preferredUsername + "/activity/" + act._uuid)
  unless act.actor
    callback new Error("Activity has no actor")
    return
  unless act.object
    callback new Error("Activity has no object")
    return
  act.content = Activity.makeContent(act)  unless act.content
  Step (->
    ActivityObject.compressProperty act, "actor", @parallel()
    ActivityObject.compressProperty act, "object", @parallel()
    ActivityObject.compressProperty act, "target", @parallel()
    ActivityObject.compressProperty act, "generator", @parallel()
    ActivityObject.compressArray act, "to", @parallel()
    ActivityObject.compressArray act, "cc", @parallel()
    ActivityObject.compressArray act, "bto", @parallel()
    ActivityObject.compressArray act, "bcc", @parallel()
  ), (err) ->
    if err
      callback err
    else
      callback null



# When get()'ing an activity, also get the actor and the object,
# which are saved by reference
Activity::afterCreate = Activity::afterSave = Activity::afterUpdate = Activity::afterGet = (callback) ->
  @expand callback

Activity::expand = (callback) ->
  act = this
  Step (->
    ActivityObject.expandProperty act, "actor", @parallel()
    ActivityObject.expandProperty act, "object", @parallel()
    ActivityObject.expandProperty act, "target", @parallel()
    ActivityObject.expandProperty act, "generator", @parallel()
    ActivityObject.expandArray act, "to", @parallel()
    ActivityObject.expandArray act, "cc", @parallel()
    ActivityObject.expandArray act, "bto", @parallel()
    ActivityObject.expandArray act, "bcc", @parallel()
  ), ((err) ->
    throw err  if err
    act.object.expandFeeds this
  ), (err) ->
    if err
      callback err
    else
      
      # Implied
      delete act.object.author  if act.verb is "post" and _(act.object).has("author")
      callback null


Activity::compress = (callback) ->
  act = this
  Step (->
    ActivityObject.compressProperty act, "actor", @parallel()
    ActivityObject.compressProperty act, "object", @parallel()
    ActivityObject.compressProperty act, "target", @parallel()
    ActivityObject.compressProperty act, "generator", @parallel()
  ), (err) ->
    if err
      callback err
    else
      callback null


Activity::efface = (callback) ->
  keepers = ["actor", "object", "_uuid", "id", "published", "deleted", "updated"]
  prop = undefined
  obj = this
  for prop of obj
    delete obj[prop]  if obj.hasOwnProperty(prop) and keepers.indexOf(prop) is -1
  now = Stamper.stamp()
  obj.deleted = obj.updated = now
  obj.save callback


# Sanitize for going out over the wire
Activity::sanitize = (user) ->
  act = this
  i = undefined
  j = undefined
  props = ["to", "cc", "bto", "bcc"]
  if not user or (user.profile.id isnt @actor.id)
    delete @bcc  if @bcc
    delete @bto  if @bto
  _.each act, (value, key) ->
    delete act[key]  if key[0] is "_"

  @actor.sanitize()  if @actor and @actor.sanitize
  @object.sanitize()  if @object and @object.sanitize
  i = 0
  while i < props.length
    if this[props[i]]
      j = 0
      while j < this[props[i]].length
        this[props[i]][j].sanitize()  if this[props[i]][j].sanitize
        j++
    i++
  return


# Is the person argument a recipient of this activity?
# Checks to, cc, bto, bcc
# If the public is a recipient, always works (even null)
# Otherwise if the person is a direct recipient, true.
# Otherwise if the person is in a list that's a recipient, true.
# Otherwise if the actor's followers list is a recipient, and the
# person is a follower, true.
# Otherwise false.
Activity::checkRecipient = (person, callback) ->
  act = this
  i = undefined
  addrProps = ["to", "cc", "bto", "bcc"]
  recipientsOfType = (type) ->
    i = undefined
    j = undefined
    addrs = undefined
    rot = []
    i = 0
    while i < addrProps.length
      if _(act).has(addrProps[i])
        addrs = act[addrProps[i]]
        j = 0
        while j < addrs.length
          rot.push addrs[j]  if addrs[j].objectType is type
          j++
      i++
    rot

  recipientWithID = (id) ->
    i = undefined
    j = undefined
    addrs = undefined
    i = 0
    while i < addrProps.length
      if _(act).has(addrProps[i])
        addrs = act[addrProps[i]]
        j = 0
        while j < addrs.length
          return addrs[j]  if addrs[j].id is id
          j++
      i++
    null

  isInLists = (person, callback) ->
    isInList = (list, callback) ->
      Step (->
        Collection.isList list, this
      ), ((err, isList) ->
        throw err  if err
        unless isList
          callback null, false
        else
          list.getStream this
      ), ((err, str) ->
        val = JSON.stringify(
          id: person.id
          objectType: person.objectType
        )
        throw err  if err
        str.indexOf val, this
      ), (err, i) ->
        if err
          if err.name is "NotInStreamError"
            callback null, false
          else
            callback err, null
        else
          callback null, true


    Step (->
      i = undefined
      group = @group()
      lists = recipientsOfType(ActivityObject.COLLECTION)
      i = 0
      while i < lists.length
        isInList lists[i], group()
        i++
    ), (err, inLists) ->
      if err
        callback err, null
      else
        callback null, inLists.some((b) ->
          b
        )


  isInFollowers = (person, callback) ->
    if not _(act).has("actor") or act.actor.objectType isnt ActivityObject.PERSON
      callback null, false
      return
    Step (->
      act.actor.followersURL this
    ), ((err, url) ->
      throw err  if err
      if not url or not recipientWithID(url)
        callback null, false
      else
        Edge = require("./edge").Edge
        Edge.get Edge.id(person.id, act.actor.id), this
    ), (err, edge) ->
      if err and err.name is "NoSuchThingError"
        callback null, false
      else unless err
        callback null, true
      else
        callback err, null


  persons = undefined
  Collection = require("./collection").Collection
  
  # Check for public
  pub = recipientWithID(Collection.PUBLIC)
  return callback(null, true)  if pub
  
  # if not public, then anonymous user can't be a recipient
  return callback(null, false)  unless person
  
  # Always OK for author to view their own activity
  return callback(null, true)  if _.has(act, "actor") and person.id is act.actor.id
  
  # Check for exact match
  persons = recipientsOfType("person")
  i = 0
  while i < persons.length
    return callback(null, true)  if persons[i].id is person.id
    i++
  
  # From here on, things go async
  Step (->
    isInLists person, @parallel()
    isInFollowers person, @parallel()
  ), (err, inlists, infollowers) ->
    if err
      callback err, null
    else
      callback null, inlists or infollowers


Activity::isMajor = ->
  alwaysVerbs = [Activity.SHARE, Activity.CHECKIN]
  exceptVerbs = {}
  return true  if alwaysVerbs.indexOf(@verb) isnt -1
  exceptVerbs[Activity.POST] = [ActivityObject.COMMENT, ActivityObject.COLLECTION]
  exceptVerbs[Activity.CREATE] = [ActivityObject.COMMENT, ActivityObject.COLLECTION]
  return true  if exceptVerbs.hasOwnProperty(@verb) and exceptVerbs[@verb].indexOf(@object.objectType) is -1
  false


# XXX: we should probably just cache this somewhere
Activity.postOf = (activityObject, callback) ->
  verbSearch = (verb, object, cb) ->
    Step (->
      Activity.search
        verb: verb
        "object.id": object.id
      , this
    ), (err, acts) ->
      matched = undefined
      if err
        cb err, null
      else if acts.length is 0
        cb null, null
      else
        
        # get first author match
        act = _.find(acts, (act) ->
          act.actor and object.author and act.actor.id is object.author.id
        )
        cb null, act


  Step (->
    verbSearch Activity.POST, activityObject, this
  ), ((err, act) ->
    throw err  if err
    if act
      callback null, act
    else
      verbSearch Activity.CREATE, activityObject, this
  ), (err, act) ->
    if err
      callback err, null
    else
      callback null, act


Activity.verbs = ["accept", "access", "acknowledge", "add", "agree", "append", "approve", "archive", "assign", "at", "attach", "attend", "author", "authorize", "borrow", "build", "cancel", "close", "complete", "confirm", "consume", "checkin", "close", "create", "delete", "deliver", "deny", "disagree", "dislike", "experience", "favorite", "find", "follow", "give", "host", "ignore", "insert", "install", "interact", "invite", "join", "leave", "like", "listen", "lose", "make-friend", "open", "play", "post", "present", "purchase", "qualify", "read", "receive", "reject", "remove", "remove-friend", "replace", "request", "request-friend", "resolve", "return", "retract", "rsvp-maybe", "rsvp-no", "rsvp-yes", "satisfy", "save", "schedule", "search", "sell", "send", "share", "sponsor", "start", "stop-following", "submit", "tag", "terminate", "tie", "unfavorite", "unlike", "unsatisfy", "unsave", "unshare", "update", "use", "watch", "win"]
i = 0
verb = undefined

# Constants-like members for activity verbs
i = 0
while i < Activity.verbs.length
  verb = Activity.verbs[i]
  Activity[verb.toUpperCase().replace("-", "_")] = verb
  i++
exports.Activity = Activity
exports.AppError = AppError
