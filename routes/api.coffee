# routes/api.js
#
# The beating heart of a pumpin' good time
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
databank = require("databank")
_ = require("underscore")
Step = require("step")
validator = require("validator")
path = require("path")
fs = require("fs")
mkdirp = require("mkdirp")
check = validator.check
sanitize = validator.sanitize
FilteredStream = require("../lib/filteredstream").FilteredStream
filters = require("../lib/filters")
recipientsOnly = filters.recipientsOnly
publicOnly = filters.publicOnly
objectRecipientsOnly = filters.objectRecipientsOnly
objectPublicOnly = filters.objectPublicOnly
idRecipientsOnly = filters.idRecipientsOnly
idPublicOnly = filters.idPublicOnly
HTTPError = require("../lib/httperror").HTTPError
Stamper = require("../lib/stamper").Stamper
Scrubber = require("../lib/scrubber")
Activity = require("../lib/model/activity").Activity
AppError = require("../lib/model/activity").AppError
Collection = require("../lib/model/collection").Collection
ActivityObject = require("../lib/model/activityobject").ActivityObject
User = require("../lib/model/user").User
Edge = require("../lib/model/edge").Edge
Favorite = require("../lib/model/favorite").Favorite
stream = require("../lib/model/stream")
Stream = stream.Stream
NotInStreamError = stream.NotInStreamError
URLMaker = require("../lib/urlmaker").URLMaker
Distributor = require("../lib/distributor")
mw = require("../lib/middleware")
omw = require("../lib/objectmiddleware")
randomString = require("../lib/randomstring").randomString
finishers = require("../lib/finishers")
mm = require("../lib/mimemap")
saveUpload = require("../lib/saveupload").saveUpload
reqUser = mw.reqUser
reqGenerator = mw.reqGenerator
sameUser = mw.sameUser
clientAuth = mw.clientAuth
userAuth = mw.userAuth
remoteUserAuth = mw.remoteUserAuth
maybeAuth = mw.maybeAuth
fileContent = mw.fileContent
requestObject = omw.requestObject
authorOnly = omw.authorOnly
authorOrRecipient = omw.authorOrRecipient
NoSuchThingError = databank.NoSuchThingError
AlreadyExistsError = databank.AlreadyExistsError
NoSuchItemError = databank.NoSuchItemError
addFollowedFinisher = finishers.addFollowedFinisher
addFollowed = finishers.addFollowed
addLikedFinisher = finishers.addLikedFinisher
addLiked = finishers.addLiked
addLikersFinisher = finishers.addLikersFinisher
addLikers = finishers.addLikers
addSharedFinisher = finishers.addSharedFinisher
addShared = finishers.addShared
firstFewRepliesFinisher = finishers.firstFewRepliesFinisher
firstFewReplies = finishers.firstFewReplies
firstFewSharesFinisher = finishers.firstFewSharesFinisher
firstFewShares = finishers.firstFewShares
doFinishers = finishers.doFinishers
typeToClass = mm.typeToClass
typeToExt = mm.typeToExt
extToType = mm.extToType
DEFAULT_ITEMS = 20
DEFAULT_ACTIVITIES = DEFAULT_ITEMS
DEFAULT_FAVORITES = DEFAULT_ITEMS
DEFAULT_LIKES = DEFAULT_ITEMS
DEFAULT_REPLIES = DEFAULT_ITEMS
DEFAULT_SHARES = DEFAULT_ITEMS
DEFAULT_FOLLOWERS = DEFAULT_ITEMS
DEFAULT_FOLLOWING = DEFAULT_ITEMS
DEFAULT_MEMBERS = DEFAULT_ITEMS
DEFAULT_USERS = DEFAULT_ITEMS
DEFAULT_LISTS = DEFAULT_ITEMS
DEFAULT_UPLOADS = DEFAULT_ITEMS
MAX_ITEMS = DEFAULT_ITEMS * 10
MAX_ACTIVITIES = MAX_ITEMS
MAX_FAVORITES = MAX_ITEMS
MAX_LIKES = MAX_ITEMS
MAX_REPLIES = MAX_ITEMS
MAX_SHARES = MAX_ITEMS
MAX_FOLLOWERS = MAX_ITEMS
MAX_FOLLOWING = MAX_ITEMS
MAX_MEMBERS = MAX_ITEMS
MAX_USERS = MAX_ITEMS
MAX_LISTS = MAX_ITEMS
MAX_UPLOADS = MAX_ITEMS

# Initialize the app controller
addRoutes = (app) ->
  i = 0
  url = undefined
  type = undefined
  authz = undefined
  
  # Users
  app.get "/api/user/:nickname", clientAuth, reqUser, getUser
  app.put "/api/user/:nickname", userAuth, reqUser, sameUser, putUser
  app.del "/api/user/:nickname", userAuth, reqUser, sameUser, delUser
  app.get "/api/user/:nickname/profile", clientAuth, reqUser, personType, getObject
  app.put "/api/user/:nickname/profile", userAuth, reqUser, sameUser, personType, reqGenerator, putObject
  
  # Feeds
  app.get "/api/user/:nickname/feed", clientAuth, reqUser, userStream
  app.post "/api/user/:nickname/feed", userAuth, reqUser, sameUser, reqGenerator, postActivity
  app.get "/api/user/:nickname/feed/major", clientAuth, reqUser, userMajorStream
  app.get "/api/user/:nickname/feed/minor", clientAuth, reqUser, userMinorStream
  app.post "/api/user/:nickname/feed/major", userAuth, reqUser, sameUser, isMajor, reqGenerator, postActivity
  app.post "/api/user/:nickname/feed/minor", userAuth, reqUser, sameUser, isMinor, reqGenerator, postActivity
  
  # Inboxen
  app.get "/api/user/:nickname/inbox", userAuth, reqUser, sameUser, userInbox
  app.post "/api/user/:nickname/inbox", remoteUserAuth, reqUser, postToInbox
  app.get "/api/user/:nickname/inbox/major", userAuth, reqUser, sameUser, userMajorInbox
  app.get "/api/user/:nickname/inbox/minor", userAuth, reqUser, sameUser, userMinorInbox
  app.get "/api/user/:nickname/inbox/direct", userAuth, reqUser, sameUser, userDirectInbox
  app.get "/api/user/:nickname/inbox/direct/major", userAuth, reqUser, sameUser, userMajorDirectInbox
  app.get "/api/user/:nickname/inbox/direct/minor", userAuth, reqUser, sameUser, userMinorDirectInbox
  
  # Followers
  app.get "/api/user/:nickname/followers", clientAuth, reqUser, userFollowers
  
  # Following
  app.get "/api/user/:nickname/following", clientAuth, reqUser, userFollowing
  app.post "/api/user/:nickname/following", clientAuth, reqUser, sameUser, reqGenerator, newFollow
  
  # Favorites
  app.get "/api/user/:nickname/favorites", clientAuth, reqUser, userFavorites
  app.post "/api/user/:nickname/favorites", clientAuth, reqUser, sameUser, reqGenerator, newFavorite
  
  # Lists
  app.get "/api/user/:nickname/lists/:type", clientAuth, reqUser, userLists
  if app.config.uploaddir
    
    # Uploads
    app.get "/api/user/:nickname/uploads", userAuth, reqUser, sameUser, userUploads
    app.post "/api/user/:nickname/uploads", userAuth, reqUser, sameUser, fileContent, newUpload
  
  # Activities
  app.get "/api/activity/:uuid", clientAuth, reqActivity, actorOrRecipient, getActivity
  app.put "/api/activity/:uuid", userAuth, reqActivity, actorOnly, putActivity
  app.del "/api/activity/:uuid", userAuth, reqActivity, actorOnly, delActivity
  
  # Other objects
  app.get "/api/:type/:uuid", clientAuth, requestObject, authorOrRecipient, getObject
  app.put "/api/:type/:uuid", userAuth, requestObject, authorOnly, reqGenerator, putObject
  app.del "/api/:type/:uuid", userAuth, requestObject, authorOnly, reqGenerator, deleteObject
  app.get "/api/:type/:uuid/likes", clientAuth, requestObject, authorOrRecipient, objectLikes
  app.get "/api/:type/:uuid/replies", clientAuth, requestObject, authorOrRecipient, objectReplies
  app.get "/api/:type/:uuid/shares", clientAuth, requestObject, authorOrRecipient, objectShares
  
  # Global user list
  app.get "/api/users", clientAuth, listUsers
  app.post "/api/users", clientAuth, reqGenerator, createUser
  
  # Collection members
  app.get "/api/collection/:uuid/members", clientAuth, requestCollection, authorOrRecipient, collectionMembers
  app.post "/api/collection/:uuid/members", userAuth, requestCollection, authorOnly, reqGenerator, newMember


# XXX: use a common function instead of faking up params
requestCollection = (req, res, next) ->
  req.params.type = "collection"
  requestObject req, res, next

personType = (req, res, next) ->
  req.type = "person"
  next()

isMajor = (req, res, next) ->
  props = Scrubber.scrubActivity(req.body)
  activity = new Activity(props)
  if activity.isMajor()
    next()
  else
    next new HTTPError("Only major activities to this feed.", 400)

isMinor = (req, res, next) ->
  props = Scrubber.scrubActivity(req.body)
  activity = new Activity(props)
  unless activity.isMajor()
    next()
  else
    next new HTTPError("Only minor activities to this feed.", 400)

userOnly = (req, res, next) ->
  person = req.person
  user = req.remoteUser
  if person and user and user.profile and person.id is user.profile.id and user.profile.objectType is "person"
    next()
  else
    next new HTTPError("Only the user can modify this profile.", 403)

actorOnly = (req, res, next) ->
  act = req.activity
  if act and act.actor and act.actor.id is req.remoteUser.profile.id
    next()
  else
    next new HTTPError("Only the actor can modify this object.", 403)

actorOrRecipient = (req, res, next) ->
  act = req.activity
  person = (if (req.remoteUser) then req.remoteUser.profile else null)
  if act and act.actor and person and act.actor.id is person.id
    next()
  else
    act.checkRecipient person, (err, isRecipient) ->
      if err
        next err
      else unless isRecipient
        next new HTTPError("Only the actor and recipients can view this activity.", 403)
      else
        next()


getObject = (req, res, next) ->
  type = req.type
  obj = req[type]
  profile = (if (req.remoteUser) then req.remoteUser.profile else null)
  Step (->
    obj.expandFeeds this
  ), ((err) ->
    throw err  if err
    addLiked profile, [obj], @parallel()
    addLikers profile, [obj], @parallel()
    addShared profile, [obj], @parallel()
    firstFewReplies profile, [obj], @parallel()
    firstFewShares profile, [obj], @parallel()
    addFollowed profile, [obj], @parallel()  if obj.isFollowable()
  ), (err) ->
    if err
      next err
    else
      obj.sanitize()
      res.json obj


putObject = (req, res, next) ->
  type = req.type
  obj = req[type]
  updates = Scrubber.scrubObject(req.body)
  act = new Activity(
    actor: req.remoteUser.profile
    generator: req.generator
    verb: "update"
    object: _(obj).extend(updates)
  )
  Step (->
    newActivity act, req.remoteUser, this
  ), (err, act) ->
    d = undefined
    if err
      next err
    else
      act.object.sanitize()
      res.json act.object
      d = new Distributor(act)
      d.distribute (err) ->



deleteObject = (req, res, next) ->
  type = req.type
  obj = req[type]
  act = new Activity(
    actor: req.remoteUser.profile
    verb: "delete"
    generator: req.generator
    object: obj
  )
  Step (->
    newActivity act, req.remoteUser, this
  ), (err, act) ->
    d = undefined
    if err
      next err
    else
      res.json "Deleted"
      d = new Distributor(act)
      d.distribute (err) ->



objectLikes = (req, res, next) ->
  type = req.type
  obj = req[type]
  collection =
    displayName: "People who like " + obj.displayName
    id: URLMaker.makeURL("api/" + type + "/" + obj._uuid + "/likes")
    items: []

  args = undefined
  try
    args = streamArgs(req, DEFAULT_LIKES, MAX_LIKES)
  catch e
    next e
    return
  Step (->
    obj.favoritersCount this
  ), ((err, count) ->
    if err
      if err.name is "NoSuchThingError"
        collection.totalItems = 0
        res.json collection
      else
        throw err
    collection.totalItems = count
    obj.getFavoriters args.start, args.end, this
  ), (err, likers) ->
    if err
      next err
    else
      collection.items = likers
      res.json collection


objectReplies = (req, res, next) ->
  type = req.type
  obj = req[type]
  collection =
    displayName: "Replies to " + ((if (obj.displayName) then obj.displayName else obj.id))
    id: URLMaker.makeURL("api/" + type + "/" + obj._uuid + "/replies")
    items: []

  args = undefined
  try
    args = streamArgs(req, DEFAULT_REPLIES, MAX_REPLIES)
  catch e
    next e
    return
  Step (->
    obj.getRepliesStream this
  ), ((err, str) ->
    filtered = undefined
    throw err  if err
    unless req.remoteUser
      
      # XXX: keep a separate stream instead of filtering
      filtered = new FilteredStream(str, objectPublicOnly)
    else
      filtered = new FilteredStream(str, objectRecipientsOnly(req.remoteUser.profile))
    filtered.count @parallel()
    filtered.getObjects args.start, args.end, @parallel()
  ), ((err, count, refs) ->
    group = @group()
    throw err  if err
    collection.totalItems = count
    _.each refs, (ref) ->
      ActivityObject.getObject ref.objectType, ref.id, group()

  ), (err, objs) ->
    if err
      next err
    else
      _.each objs, (obj) ->
        obj.sanitize()
        delete obj.inReplyTo

      collection.items = objs
      res.json collection



# Feed of actors (usually persons) who have shared the object
# It's stored as a stream, so we get those
objectShares = (req, res, next) ->
  type = req.type
  obj = req[type]
  collection =
    displayName: "Shares of " + ((if (obj.displayName) then obj.displayName else obj.id))
    id: URLMaker.makeURL("api/" + type + "/" + obj._uuid + "/shares")
    items: []

  args = undefined
  try
    args = streamArgs(req, DEFAULT_SHARES, MAX_SHARES)
  catch e
    next e
    return
  Step (->
    obj.getSharesStream this
  ), ((err, str) ->
    filtered = undefined
    throw err  if err
    str.count @parallel()
    str.getObjects args.start, args.end, @parallel()
  ), ((err, count, refs) ->
    group = @group()
    throw err  if err
    collection.totalItems = count
    _.each refs, (ref) ->
      ActivityObject.getObject ref.objectType, ref.id, group()

  ), (err, objs) ->
    if err
      next err
    else
      _.each objs, (obj) ->
        obj.sanitize()

      collection.items = objs
      res.json collection


getUser = (req, res, next) ->
  Step (->
    req.user.profile.expandFeeds this
  ), ((err) ->
    throw err  if err
    unless req.remoteUser
      
      # skip
      this null
    else if req.remoteUser.nickname is req.user.nickname
      
      # same user
      req.user.profile.pump_io = followed: false
      
      # skip
      this null
    else
      addFollowed req.remoteUser.profile, [req.user.profile], this
  ), (err) ->
    next err  if err
    
    # If no user, or different user, hide email
    delete req.user.email  if not req.remoteUser or (req.remoteUser.nickname isnt req.user.nickname)
    req.user.sanitize()
    res.json req.user


putUser = (req, res, next) ->
  newUser = req.body
  req.user.update newUser, (err, saved) ->
    if err
      next err
    else
      saved.sanitize()
      res.json saved


delUser = (req, res, next) ->
  user = req.user
  Step (->
    user.del this
  ), ((err) ->
    throw err  if err
    usersStream this
  ), ((err, str) ->
    throw err  if err
    str.remove user.nickname, this
  ), (err) ->
    if err
      next err
    else
      res.json "Deleted."


reqActivity = (req, res, next) ->
  act = null
  uuid = req.params.uuid
  Activity.search
    _uuid: uuid
  , (err, results) ->
    if err
      next err
    else if results.length is 0 # not found
      next new HTTPError("Can't find an activity with id " + uuid, 404)
    else if results.length > 1
      next new HTTPError("Too many activities with ID = " + req.params.uuid, 500)
    else
      act = results[0]
      if act.hasOwnProperty("deleted")
        next new HTTPError("Deleted", 410)
      else
        act.expand (err) ->
          if err
            next err
          else
            req.activity = act
            next()



getActivity = (req, res, next) ->
  user = req.remoteUser
  act = req.activity
  act.sanitize user
  res.json act

putActivity = (req, res, next) ->
  update = Scrubber.scrubActivity(req.body)
  req.activity.update update, (err, result) ->
    if err
      next err
    else
      result.sanitize req.remoteUser
      res.json result


delActivity = (req, res, next) ->
  act = req.activity
  Step (->
    act.efface this
  ), (err) ->
    if err
      next err
    else
      res.json "Deleted"



# Get the stream of all users
usersStream = (callback) ->
  Step (->
    Stream.get "user:all", this
  ), ((err, str) ->
    if err
      if err.name is "NoSuchThingError"
        Stream.create
          name: "user:all"
        , this
      else
        throw err
    else
      callback null, str
  ), (err, str) ->
    if err
      if err.name is "AlreadyExistsError"
        Stream.get "user:all", callback
      else
        callback err
    else
      callback null, str


thisService = (app) ->
  Service = require("../lib/model/service").Service
  new Service(
    url: URLMaker.makeURL("/")
    displayName: app.config.site or "pump.io"
  )

createUser = (req, res, next) ->
  user = undefined
  props = req.body
  registrationActivity = (user, svc, callback) ->
    act = new Activity(
      actor: user.profile
      verb: Activity.JOIN
      object: svc
      generator: req.generator
    )
    newActivity act, user, callback

  welcomeActivity = (user, svc, callback) ->
    Step (->
      res.render "welcome",
        page:
          title: "Welcome"

        data:
          profile: user.profile
          service: svc

        layout: false
      , this
    ), ((err, text) ->
      throw err  if err
      act = new Activity(
        actor: svc
        verb: Activity.POST
        to: [user.profile]
        object:
          objectType: ActivityObject.NOTE
          displayName: "Welcome to " + svc.displayName
          content: text
      )
      initActivity act, this
    ), (err, act) ->
      if err
        callback err, null
      else
        callback null, act


  defaultLists = (user, callback) ->
    Step ((err, str) ->
      lists = ["Friends", "Family", "Acquaintances", "Coworkers"]
      group = @group()
      throw err  if err
      _.each lists, (list) ->
        act = new Activity(
          verb: Activity.CREATE
          to: [
            objectType: ActivityObject.COLLECTION
            id: user.profile.followers.url
          ]
          object:
            objectType: ActivityObject.COLLECTION
            displayName: list
            objectTypes: ["person"]
        )
        newActivity act, user, group()

    ), callback

  
  # Email validation
  if _.has(req.app.config, "requireEmail") and req.app.config.requireEmail
    if not _.has(props, "email") or not _.isString(props.email) or props.email.length is 0
      next new HTTPError("No email address", 400)
      return
    else
      try
        check(props.email).isEmail()
      catch e
        next new HTTPError(e.message, 400)
        return
  Step (->
    User.create props, this
  ), ((err, value) ->
    if err
      
      # Try to be more specific
      if err instanceof User.BadPasswordError
        throw new HTTPError(err.message, 400)
      else if err instanceof User.BadNicknameError
        throw new HTTPError(err.message, 400)
      else if err.name is "AlreadyExistsError"
        throw new HTTPError(err.message, 409) # conflict
      else
        throw err
    user = value
    usersStream this
  ), ((err, str) ->
    throw err  if err
    str.deliver user.nickname, this
  ), ((err) ->
    throw err  if err
    user.expand this
  ), ((err) ->
    svc = undefined
    throw err  if err
    svc = thisService(req.app)
    registrationActivity user, svc, @parallel()
    welcomeActivity user, svc, @parallel()
    defaultLists user, @parallel()
  ), ((err, reg, welcome, lists) ->
    rd = undefined
    wd = undefined
    group = @group()
    throw err  if err
    rd = new Distributor(reg)
    rd.distribute group()
    wd = new Distributor(welcome)
    wd.distribute group()
    _.each lists, (list) ->
      d = new Distributor(list)
      d.distribute group()

  ), ((err) ->
    throw err  if err
    req.app.provider.newTokenPair req.client, user, this
  ), (err, pair) ->
    if err
      next err
    else
      
      # Hide the password for output
      user.sanitize()
      user.token = pair.access_token
      user.secret = pair.token_secret
      
      # If called as /main/register; see ./web.js
      # XXX: Bad hack
      if req.session
        req.session.principal =
          id: user.profile.id
          objectType: user.profile.objectType
      res.json user


listUsers = (req, res, next) ->
  url = URLMaker.makeURL("api/users")
  collection =
    displayName: "Users of this service"
    id: url
    objectTypes: ["user"]
    links:
      first:
        href: url

      self:
        href: url

  args = undefined
  str = undefined
  try
    args = streamArgs(req, DEFAULT_USERS, MAX_USERS)
  catch e
    next e
    return
  Step (->
    usersStream this
  ), ((err, result) ->
    throw err  if err
    str = result
    str.count this
  ), ((err, totalUsers) ->
    throw err  if err
    collection.totalItems = totalUsers
    if totalUsers is 0
      collection.items = []
      res.json collection
      return
    else
      if _(args).has("before")
        str.getIDsGreaterThan args.before, args.count, this
      else if _(args).has("since")
        str.getIDsLessThan args.since, args.count, this
      else
        str.getIDs args.start, args.end, this
  ), ((err, userIds) ->
    throw err  if err
    User.readArray userIds, this
  ), (err, users) ->
    i = undefined
    throw err  if err
    _.each users, (user) ->
      user.sanitize()
      delete user.email  if not req.remoteUser or req.remoteUser.nickname isnt user.nickname

    collection.items = users
    if users.length > 0
      collection.links.prev = href: url + "?since=" + encodeURIComponent(users[0].nickname)
      collection.links.next = href: url + "?before=" + encodeURIComponent(users[users.length - 1].nickname)  if (_(args).has("start") and args.start + users.length < collection.totalItems) or (_(args).has("before") and users.length >= args.count) or (_(args).has("since"))
    res.json collection


postActivity = (req, res, next) ->
  props = Scrubber.scrubActivity(req.body)
  activity = new Activity(props)
  
  # Add a default actor
  activity.actor = req.user.profile  unless _(activity).has("actor")
  
  # If the actor is incorrect, error
  if activity.actor.id isnt req.user.profile.id
    next new HTTPError("Invalid actor", 400)
    return
  
  # XXX: we overwrite anything here
  activity.generator = req.generator
  
  # Default verb
  activity.verb = "post"  if not _(activity).has("verb") or _(activity.verb).isNull()
  Step (->
    newActivity activity, req.user, this
  ), (err, activity) ->
    d = undefined
    if err
      next err
    else
      activity.sanitize()
      
      # ...then show (possibly modified) results.
      res.json activity
      
      # ...then distribute.
      d = new Distributor(activity)
      d.distribute (err) ->



postToInbox = (req, res, next) ->
  props = Scrubber.scrubActivity(req.body)
  activity = new Activity(props)
  user = req.user
  
  # Check for actor
  next new HTTPError("Invalid actor", 400)  unless _(activity).has("actor")
  
  # If the actor is incorrect, error
  unless ActivityObject.sameID(activity.actor.id, req.webfinger)
    next new HTTPError("Invalid actor", 400)
    return
  
  # Default verb
  activity.verb = "post"  if not _(activity).has("verb") or _(activity.verb).isNull()
  
  # Add a received timestamp
  activity.received = Stamper.stamp()
  
  # TODO: return a 202 Accepted here?
  Step (->
    
    # First, ensure recipients
    activity.ensureRecipients this
  ), ((err) ->
    throw err  if err
    
    # apply the activity
    activity.apply null, this
  ), ((err) ->
    if err
      if err.name is "AppError"
        throw new HTTPError(err.message, 400)
      else if err.name is "NoSuchThingError"
        throw new HTTPError(err.message, 400)
      else if err.name is "AlreadyExistsError"
        throw new HTTPError(err.message, 400)
      else if err.name is "NoSuchItemError"
        throw new HTTPError(err.message, 400)
      else if err.name is "NotInStreamError"
        throw new HTTPError(err.message, 400)
      else
        throw err
    
    # ...then persist...
    activity.save this
  ), ((err, saved) ->
    throw err  if err
    activity = saved
    user.addToInbox activity, @parallel()
  ), (err) ->
    if err
      next err
    else
      activity.sanitize()
      
      # ...then show (possibly modified) results.
      # XXX: don't distribute
      res.json activity


initActivity = (activity, callback) ->
  Step (->
    
    # First, ensure recipients
    activity.ensureRecipients this
  ), ((err) ->
    throw err  if err
    
    # First, apply the activity
    activity.apply null, this
  ), ((err) ->
    if err
      if err.name is "AppError"
        throw new HTTPError(err.message, 400)
      else if err.name is "NoSuchThingError"
        throw new HTTPError(err.message, 400)
      else if err.name is "AlreadyExistsError"
        throw new HTTPError(err.message, 400)
      else if err.name is "NoSuchItemError"
        throw new HTTPError(err.message, 400)
      else if err.name is "NotInStreamError"
        throw new HTTPError(err.message, 400)
      else
        throw err
    
    # ...then persist...
    activity.save this
  ), (err, saved) ->
    if err
      callback err, null
    else
      callback null, activity


newActivity = (activity, user, callback) ->
  activity.actor = user.profile  unless _(activity).has("actor")
  Step (->
    initActivity activity, this
  ), ((err, saved) ->
    throw err  if err
    activity = saved
    user.addToOutbox activity, @parallel()
    user.addToInbox activity, @parallel()
  ), (err) ->
    if err
      callback err, null
    else
      callback null, activity


filteredFeedRoute = (urlmaker, titlemaker, streammaker, finisher) ->
  (req, res, next) ->
    url = urlmaker(req)
    collection =
      author: req.user.profile
      displayName: titlemaker(req)
      id: url
      objectTypes: ["activity"]
      url: url
      links:
        first:
          href: url

        self:
          href: url

      items: []

    args = undefined
    str = undefined
    ids = undefined
    try
      args = streamArgs(req, DEFAULT_ACTIVITIES, MAX_ACTIVITIES)
    catch e
      next e
      return
    Step (->
      streammaker req, this
    ), ((err, outbox) ->
      if err
        if err.name is "NoSuchThingError"
          collection.totalItems = 0
          res.json collection
        else
          throw err
      else
        
        # Skip filtering if remote user == author
        if req.remoteUser and req.remoteUser.profile.id is req.user.profile.id
          str = outbox
        else unless req.remoteUser
          
          # XXX: keep a separate stream instead of filtering
          str = new FilteredStream(outbox, publicOnly)
        else
          str = new FilteredStream(outbox, recipientsOnly(req.remoteUser.profile))
        getStream str, args, collection, req.remoteUser, this
    ), ((err) ->
      throw err  if err
      if finisher
        finisher req, collection, this
      else
        this null
    ), (err) ->
      if err
        next err
      else
        collection.items.forEach (act) ->
          delete act.actor

        collection.author.sanitize()  if _.has(collection, "author")
        res.json collection


majorFinishers = doFinishers([addLikedFinisher, firstFewRepliesFinisher, addLikersFinisher, addSharedFinisher, firstFewSharesFinisher])
userStream = filteredFeedRoute((req) ->
  URLMaker.makeURL "api/user/" + req.user.nickname + "/feed"
, (req) ->
  "Activities by " + (req.user.profile.displayName or req.user.nickname)
, (req, callback) ->
  req.user.getOutboxStream callback
)
userMajorStream = filteredFeedRoute((req) ->
  URLMaker.makeURL "api/user/" + req.user.nickname + "/feed/major"
, (req) ->
  "Major activities by " + (req.user.profile.displayName or req.user.nickname)
, (req, callback) ->
  req.user.getMajorOutboxStream callback
, majorFinishers)
userMinorStream = filteredFeedRoute((req) ->
  URLMaker.makeURL "api/user/" + req.user.nickname + "/feed/minor"
, (req) ->
  "Minor activities by " + (req.user.profile.displayName or req.user.nickname)
, (req, callback) ->
  req.user.getMinorOutboxStream callback
)
feedRoute = (urlmaker, titlemaker, streamgetter, finisher) ->
  (req, res, next) ->
    url = urlmaker(req)
    collection =
      author: req.user.profile
      displayName: titlemaker(req)
      id: url
      objectTypes: ["activity"]
      url: url
      links:
        first:
          href: url

        self:
          href: url

      items: []

    args = undefined
    str = undefined
    try
      args = streamArgs(req, DEFAULT_ACTIVITIES, MAX_ACTIVITIES)
    catch e
      next e
      return
    Step (->
      streamgetter req, this
    ), ((err, inbox) ->
      if err
        if err.name is "NoSuchThingError"
          collection.totalItems = 0
          collection.author.sanitize()  if _.has(collection, "author")
          res.json collection
        else
          throw err
      else
        getStream inbox, args, collection, req.remoteUser, this
    ), ((err) ->
      throw err  if err
      if finisher
        finisher req, collection, this
      else
        this null
    ), (err) ->
      if err
        next err
      else
        collection.author.sanitize()  if _.has(collection, "author")
        res.json collection


userInbox = feedRoute((req) ->
  URLMaker.makeURL "api/user/" + req.user.nickname + "/inbox"
, (req) ->
  "Activities for " + (req.user.profile.displayName or req.user.nickname)
, (req, callback) ->
  req.user.getInboxStream callback
)
userMajorInbox = feedRoute((req) ->
  URLMaker.makeURL "api/user/" + req.user.nickname + "/inbox/major"
, (req) ->
  "Major activities for " + (req.user.profile.displayName or req.user.nickname)
, (req, callback) ->
  req.user.getMajorInboxStream callback
, majorFinishers)
userMinorInbox = feedRoute((req) ->
  URLMaker.makeURL "api/user/" + req.user.nickname + "/inbox/minor"
, (req) ->
  "Minor activities for " + (req.user.profile.displayName or req.user.nickname)
, (req, callback) ->
  req.user.getMinorInboxStream callback
)
userDirectInbox = feedRoute((req) ->
  URLMaker.makeURL "api/user/" + req.user.nickname + "/inbox/direct"
, (req) ->
  "Activities directly for " + (req.user.profile.displayName or req.user.nickname)
, (req, callback) ->
  req.user.getDirectInboxStream callback
)
userMajorDirectInbox = feedRoute((req) ->
  URLMaker.makeURL "api/user/" + req.user.nickname + "/inbox/direct/major"
, (req) ->
  "Major activities directly for " + (req.user.profile.displayName or req.user.nickname)
, (req, callback) ->
  req.user.getMajorDirectInboxStream callback
, majorFinishers)
userMinorDirectInbox = feedRoute((req) ->
  URLMaker.makeURL "api/user/" + req.user.nickname + "/inbox/direct/minor"
, (req) ->
  "Minor activities directly for " + (req.user.profile.displayName or req.user.nickname)
, (req, callback) ->
  req.user.getMinorDirectInboxStream callback
)
getStream = (str, args, collection, user, callback) ->
  Step (->
    str.count this
  ), ((err, totalItems) ->
    throw err  if err
    collection.totalItems = totalItems
    if totalItems is 0
      callback null
      return
    if _(args).has("before")
      str.getIDsGreaterThan args.before, args.count, this
    else if _(args).has("since")
      str.getIDsLessThan args.since, args.count, this
    else
      str.getIDs args.start, args.end, this
  ), ((err, ids) ->
    if err
      if err.name is "NotInStreamError"
        throw new HTTPError(err.message, 400)
      else
        throw err
    Activity.readArray ids, this
  ), (err, activities) ->
    if err
      callback err
    else
      activities.forEach (act) ->
        act.sanitize user

      collection.items = activities
      if activities.length > 0
        collection.links.prev = href: collection.url + "?since=" + encodeURIComponent(activities[0].id)
        collection.links.next = href: collection.url + "?before=" + encodeURIComponent(activities[activities.length - 1].id)  if (_(args).has("start") and args.start + activities.length < collection.totalItems) or (_(args).has("before") and activities.length >= args.count) or (_(args).has("since"))
      callback null


userFollowers = (req, res, next) ->
  collection =
    author: req.user.profile
    displayName: "Followers for " + (req.user.profile.displayName or req.user.nickname)
    id: URLMaker.makeURL("api/user/" + req.user.nickname + "/followers")
    objectTypes: ["person"]
    items: []

  args = undefined
  try
    args = streamArgs(req, DEFAULT_FOLLOWERS, MAX_FOLLOWERS)
  catch e
    next e
    return
  Step (->
    req.user.followerCount this
  ), ((err, count) ->
    if err
      if err.name is "NoSuchThingError"
        collection.totalItems = 0
        collection.author.sanitize()  if _.has(collection, "author")
        res.json collection
      else
        throw err
    else
      collection.totalItems = count
      req.user.getFollowers args.start, args.end, this
  ), ((err, people) ->
    throw err  if err
    collection.items = people
    unless req.remoteUser
      this null
    else
      addFollowed req.remoteUser.profile, people, this
  ), (err) ->
    base = "api/user/" + req.user.nickname + "/followers"
    if err
      next err
    else
      _.each collection.items, (person) ->
        person.sanitize()

      collection.startIndex = args.start
      collection.itemsPerPage = args.count
      collection.links =
        self:
          href: URLMaker.makeURL(base,
            offset: args.start
            count: args.count
          )

        current:
          href: URLMaker.makeURL(base)

      if args.start > 0
        collection.links.prev = href: URLMaker.makeURL(base,
          offset: Math.max(args.start - args.count, 0)
          count: Math.min(args.count, args.start)
        )
      if args.start + collection.items.length < collection.totalItems
        collection.links.next = href: URLMaker.makeURL("api/user/" + req.user.nickname + "/followers",
          offset: args.start + collection.items.length
          count: args.count
        )
      collection.author.sanitize()  if _.has(collection, "author")
      res.json collection


userFollowing = (req, res, next) ->
  collection =
    author: req.user.profile
    displayName: "People that " + (req.user.profile.displayName or req.user.nickname) + " is following"
    id: URLMaker.makeURL("api/user/" + req.user.nickname + "/following")
    objectTypes: ["person"]
    items: []

  args = undefined
  try
    args = streamArgs(req, DEFAULT_FOLLOWING, MAX_FOLLOWING)
  catch e
    next e
    return
  Step (->
    req.user.followingCount this
  ), ((err, count) ->
    if err
      if err.name is "NoSuchThingError"
        collection.totalItems = 0
        collection.author.sanitize()  if _.has(collection, "author")
        res.json collection
      else
        throw err
    else
      collection.totalItems = count
      req.user.getFollowing args.start, args.end, this
  ), ((err, people) ->
    throw err  if err
    collection.items = people
    unless req.remoteUser
      
      # Same user; by definition, all are followed
      this null
    else if req.remoteUser.nickname is req.user.nickname
      
      # Same user; by definition, all are followed
      _.each people, (person) ->
        person.pump_io = {}  unless _.has(person, "pump_io")
        person.pump_io.followed = true

      this null
    else
      addFollowed req.remoteUser.profile, people, this
  ), (err) ->
    base = "api/user/" + req.user.nickname + "/following"
    if err
      next err
    else
      _.each collection.items, (person) ->
        person.sanitize()

      collection.startIndex = args.start
      collection.itemsPerPage = args.count
      collection.links =
        self:
          href: URLMaker.makeURL(base,
            offset: args.start
            count: args.count
          )

        current:
          href: URLMaker.makeURL(base)

      if args.start > 0
        collection.links.prev = href: URLMaker.makeURL(base,
          offset: Math.max(args.start - args.count, 0)
          count: Math.min(args.count, args.start)
        )
      if args.start + collection.items.length < collection.totalItems
        collection.links.next = href: URLMaker.makeURL("api/user/" + req.user.nickname + "/following",
          offset: args.start + collection.items.length
          count: args.count
        )
      collection.author.sanitize()  if _.has(collection, "author")
      res.json collection


newFollow = (req, res, next) ->
  obj = Scrubber.scrubObject(req.body)
  act = new Activity(
    actor: req.user.profile
    verb: "follow"
    object: obj
    generator: req.generator
  )
  Step (->
    newActivity act, req.user, this
  ), (err, act) ->
    d = undefined
    if err
      next err
    else
      act.object.sanitize()
      res.json act.object
      d = new Distributor(act)
      d.distribute (err) ->



userFavorites = (req, res, next) ->
  collection =
    author: req.user.profile
    displayName: "Things that " + (req.user.profile.displayName or req.user.nickname) + " has favorited"
    id: URLMaker.makeURL("api/user/" + req.user.nickname + "/favorites")
    items: []

  args = undefined
  stream = undefined
  try
    args = streamArgs(req, DEFAULT_FAVORITES, MAX_FAVORITES)
  catch e
    next e
    return
  Step (->
    req.user.favoritesStream this
  ), ((err, result) ->
    str = undefined
    throw err  if err
    stream = result
    stream.count this
  ), ((err, cnt) ->
    str = undefined
    throw err  if err
    collection.totalItems = cnt
    if cnt is 0
      collection.author.sanitize()  if _.has(collection, "author")
      res.json collection
      return
    if req.remoteUser and req.remoteUser.profile.id is req.user.profile.id
      
      # Same user, don't filter
      str = stream
    else unless req.remoteUser
      
      # Public user, filter
      str = new FilteredStream(stream, objectPublicOnly)
    else
      
      # Registered user, filter
      str = new FilteredStream(stream, objectRecipientsOnly(req.remoteUser.profile))
    str.getObjects args.start, args.end, this
  ), ((err, refs) ->
    group = @group()
    throw err  if err
    _.each refs, (ref) ->
      
      # XXX: expand?
      # XXX: expand feeds, too?
      ActivityObject.getObject ref.objectType, ref.id, group()

  ), ((err, objects) ->
    group = @group()
    throw err  if err
    collection.items = objects
    _.each objects, (object) ->
      object.expandFeeds group()

  ), ((err) ->
    third = undefined
    profile = (if (req.remoteUser) then req.remoteUser.profile else null)
    throw err  if err
    
    # Add the first few replies for each object
    firstFewReplies profile, collection.items, @parallel()
    
    # Add the first few replies for each object
    firstFewShares profile, collection.items, @parallel()
    
    # Add the first few "likers" for each object
    addLikers profile, collection.items, @parallel()
    
    # Add the shared flag for each object
    addShared profile, collection.items, @parallel()
    third = @parallel()
    unless req.remoteUser
      
      # No user, no liked
      third null
    else if req.remoteUser.profile.id is req.user.profile.id
      
      # Same user, all liked (by definition!)
      _.each collection.items, (object) ->
        object.liked = true

      third null
    else
      
      # Different user; check for likes
      addLiked req.remoteUser.profile, collection.items, third
  ), (err) ->
    if err
      next err
    else
      _.each collection.items, (object) ->
        object.sanitize()

      collection.author.sanitize()  if _.has(collection, "author")
      res.json collection


newFavorite = (req, res, next) ->
  obj = Scrubber.scrubObject(req.body)
  act = new Activity(
    actor: req.user.profile
    verb: "favorite"
    object: obj
    generator: req.generator
  )
  Step (->
    newActivity act, req.user, this
  ), (err, act) ->
    d = undefined
    if err
      next err
    else
      act.object.sanitize()
      res.json act.object
      d = new Distributor(act)
      d.distribute (err) ->



userLists = (req, res, next) ->
  type = req.params.type
  profile = (if (req.remoteUser) then req.remoteUser.profile else null)
  url = URLMaker.makeURL("api/user/" + req.user.nickname + "/lists/" + type)
  collection =
    author: req.user.profile
    displayName: "Collections of " + type + "s for " + (req.user.profile.displayName or req.user.nickname)
    id: url
    objectTypes: ["collection"]
    url: url
    links:
      first:
        href: url

      self:
        href: url

    items: []

  args = undefined
  lists = undefined
  stream = undefined
  try
    args = streamArgs(req, DEFAULT_LISTS, MAX_LISTS)
  catch e
    next e
    return
  Step (->
    req.user.getLists type, this
  ), ((err, result) ->
    throw err  if err
    stream = result
    stream.count this
  ), ((err, totalItems) ->
    filtered = undefined
    throw err  if err
    collection.totalItems = totalItems
    if totalItems is 0
      collection.author.sanitize()  if _.has(collection, "author")
      res.json collection
      return
    unless profile
      filtered = new FilteredStream(stream, idPublicOnly(Collection.type))
    else if profile.id is req.user.profile.id
      filtered = stream
    else
      filtered = new FilteredStream(stream, idRecipientsOnly(profile, Collection.type))
    if _(args).has("before")
      filtered.getIDsGreaterThan args.before, args.count, this
    else if _(args).has("since")
      filtered.getIDsLessThan args.since, args.count, this
    else
      filtered.getIDs args.start, args.end, this
  ), ((err, ids) ->
    if err
      if err.name is "NotInStreamError"
        throw new HTTPError(err.message, 400)
      else
        throw err
    Collection.readArray ids, this
  ), ((err, results) ->
    group = @group()
    throw err  if err
    lists = results
    _.each lists, (list) ->
      list.expandFeeds group()

  ), (err) ->
    if err
      next err
    else
      _.each lists, (item) ->
        item.sanitize()

      collection.items = lists
      if lists.length > 0
        collection.links.prev = href: collection.url + "?since=" + encodeURIComponent(lists[0].id)
        collection.links.next = href: collection.url + "?before=" + encodeURIComponent(lists[lists.length - 1].id)  if (_(args).has("start") and args.start + lists.length < collection.totalItems) or (_(args).has("before") and lists.length >= args.count) or (_(args).has("since"))
      collection.author.sanitize()  if _.has(collection, "author")
      res.json collection


userUploads = (req, res, next) ->
  url = URLMaker.makeURL("api/user/" + req.user.nickname + "/uploads")
  collection =
    author: req.user.profile
    displayName: "Uploads by " + (req.user.profile.displayName or req.user.nickname)
    id: url
    objectTypes: ["file", "image", "audio", "video"]
    url: url
    links:
      first:
        href: url

      self:
        href: url

    items: []

  args = undefined
  uploads = undefined
  try
    args = streamArgs(req, DEFAULT_UPLOADS, MAX_UPLOADS)
  catch e
    next e
    return
  Step (->
    req.user.uploadsStream this
  ), ((err, stream) ->
    throw err  if err
    uploads = stream
    uploads.count this
  ), ((err, totalItems) ->
    throw err  if err
    collection.totalItems = totalItems
    if totalItems is 0
      collection.author.sanitize()  if _.has(collection, "author")
      res.json collection
      return
    if _(args).has("before")
      uploads.getObjectsGreaterThan args.before, args.count, this
    else if _(args).has("since")
      uploads.getObjectsLessThan args.since, args.count, this
    else
      uploads.getObjects args.start, args.end, this
  ), ((err, refs) ->
    group = undefined
    if err
      if err.name is "NotInStreamError"
        throw new HTTPError(err.message, 400)
      else
        throw err
    group = @group()
    _.each refs, (ref) ->
      ActivityObject.getObject ref.objectType, ref.id, group()

  ), (err, objects) ->
    if err
      next err
    else
      _.each objects, (object) ->
        object.sanitize()

      collection.items = objects
      collection.author.sanitize()  if _.has(collection, "author")
      res.json collection


newUpload = (req, res, next) ->
  user = req.remoteUser
  mimeType = req.uploadMimeType
  fileName = req.uploadFile
  uploadDir = req.app.config.uploaddir
  Step (->
    saveUpload user, mimeType, fileName, uploadDir, this
  ), (err, obj) ->
    if err
      next err
    else
      obj.sanitize()
      res.json obj


collectionMembers = (req, res, next) ->
  coll = req.collection
  profile = (if (req.remoteUser) then req.remoteUser.profile else null)
  base = "/api/collection/" + coll._uuid + "/members"
  url = URLMaker.makeURL(base)
  feed =
    author: coll.author
    displayName: "Members of " + (coll.displayName or "a collection") + " by " + coll.author.displayName
    id: url
    objectTypes: coll.objectTypes
    links:
      first:
        href: url

    items: []

  args = undefined
  str = undefined
  try
    args = streamArgs(req, DEFAULT_MEMBERS, MAX_MEMBERS)
  catch e
    next e
    return
  Step (->
    coll.getStream this
  ), ((err, result) ->
    throw err  if err
    str = result
    str.count this
  ), ((err, count) ->
    filtered = undefined
    if err
      if err.name is "NoSuchThingError"
        feed.totalItems = 0
        feed.author.sanitize()  if _.has(feed, "author")
        res.json feed
        return
      else
        throw err
    else
      feed.totalItems = count
      unless profile
        filtered = new FilteredStream(str, objectPublicOnly)
      else if profile.id is coll.author.id
        
        # no filter
        filtered = str
      else
        filtered = new FilteredStream(str, objectRecipientsOnly(profile))
      filtered.getObjects args.start, args.end, this
  ), ((err, refs) ->
    group = undefined
    throw err  if err
    group = @group()
    _.each refs, (ref) ->
      ActivityObject.getObject ref.objectType, ref.id, group()

  ), ((err, objects) ->
    third = undefined
    followable = undefined
    throw err  if err
    feed.items = objects
    
    # Add the first few replies for each object
    firstFewReplies profile, feed.items, @parallel()
    
    # Add the first few shares for each object
    firstFewShares profile, feed.items, @parallel()
    
    # Add the first few "likers" for each object
    addLikers profile, feed.items, @parallel()
    third = @parallel()
    unless profile
      
      # No user, no liked
      third null
    else
      
      # Different user; check for likes
      addLiked profile, feed.items, third
    followable = _.filter(feed.items, (obj) ->
      obj.isFollowable()
    )
    addFollowed profile, followable, @parallel()
  ), (err) ->
    if err
      next err
    else
      _.each feed.items, (obj) ->
        obj.sanitize()

      feed.startIndex = args.start
      feed.itemsPerPage = args.count
      feed.links =
        self:
          href: URLMaker.makeURL(base,
            offset: args.start
            count: args.count
          )

        current:
          href: URLMaker.makeURL(base)

      if args.start > 0
        feed.links.prev = href: URLMaker.makeURL(base,
          offset: Math.max(args.start - args.count, 0)
          count: Math.min(args.count, args.start)
        )
      if args.start + feed.items.length < feed.totalItems
        feed.links.next = href: URLMaker.makeURL(base,
          offset: args.start + feed.items.length
          count: args.count
        )
      feed.author.sanitize()  if _.has(feed, "author")
      res.json feed


newMember = (req, res, next) ->
  coll = req.collection
  obj = Scrubber.scrubObject(req.body)
  act = new Activity(
    verb: "add"
    object: obj
    target: coll
    generator: req.generator
  )
  Step (->
    newActivity act, req.remoteUser, this
  ), (err, act) ->
    d = undefined
    if err
      next err
    else
      act.object.sanitize()
      res.json act.object
      d = new Distributor(act)
      d.distribute (err) ->




# Since most stream endpoints take the same arguments,
# consolidate validation and parsing here
streamArgs = (req, defaultCount, maxCount) ->
  args = {}
  try
    maxCount = 10 * defaultCount  if _(maxCount).isUndefined()
    if _(req.query).has("count")
      check(req.query.count, "Count must be between 0 and " + maxCount).isInt().min(0).max maxCount
      args.count = sanitize(req.query.count).toInt()
    else
      args.count = defaultCount
    
    # XXX: Check "before" and "since" for injection...?
    # XXX: Check "before" and "since" for URI...?
    if _(req.query).has("before")
      check(req.query.before).notEmpty()
      args.before = sanitize(req.query.before).trim()
    if _(req.query).has("since")
      throw new Error("Can't have both 'before' and 'since' parameters")  if _(args).has("before")
      check(req.query.since).notEmpty()
      args.since = sanitize(req.query.since).trim()
    if _(req.query).has("offset")
      throw new Error("Can't have both 'before' and 'offset' parameters")  if _(args).has("before")
      throw new Error("Can't have both 'since' and 'offset' parameters")  if _(args).has("since")
      check(req.query.offset, "Offset must be an integer greater than or equal to zero").isInt().min 0
      args.start = sanitize(req.query.offset).toInt()
    args.start = 0  if not _(req.query).has("offset") and not _(req.query).has("since") and not _(req.query).has("before")
    args.end = args.start + args.count  if _(args).has("start")
    return args
  catch e
    throw new HTTPError(e.message, 400)

exports.addRoutes = addRoutes
exports.createUser = createUser
