# routes/web.js
#
# Spurtin' out pumpy goodness all over your browser window
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
url = require("url")
path = require("path")
fs = require("fs")
Step = require("step")
_ = require("underscore")
FilteredStream = require("../lib/filteredstream").FilteredStream
filters = require("../lib/filters")
publicOnly = filters.publicOnly
objectPublicOnly = filters.objectPublicOnly
recipientsOnly = filters.recipientsOnly
objectRecipientsOnly = filters.objectRecipientsOnly
always = filters.always
Activity = require("../lib/model/activity").Activity
ActivityObject = require("../lib/model/activityobject").ActivityObject
AccessToken = require("../lib/model/accesstoken").AccessToken
User = require("../lib/model/user").User
Collection = require("../lib/model/collection").Collection
mw = require("../lib/middleware")
omw = require("../lib/objectmiddleware")
sa = require("../lib/sessionauth")
he = require("../lib/httperror")
Scrubber = require("../lib/scrubber")
finishers = require("../lib/finishers")
saveUpload = require("../lib/saveupload").saveUpload
api = require("./api")
HTTPError = he.HTTPError
reqUser = mw.reqUser
reqGenerator = mw.reqGenerator
principal = sa.principal
setPrincipal = sa.setPrincipal
clearPrincipal = sa.clearPrincipal
principalUserOnly = sa.principalUserOnly
clientAuth = mw.clientAuth
userAuth = mw.userAuth
NoSuchThingError = databank.NoSuchThingError
createUser = api.createUser
addLiked = finishers.addLiked
addShared = finishers.addShared
addLikers = finishers.addLikers
firstFewReplies = finishers.firstFewReplies
firstFewShares = finishers.firstFewShares
addFollowed = finishers.addFollowed
requestObject = omw.requestObject
addRoutes = (app) ->
  app.get "/", app.session, principal, showMain
  app.get "/main/register", app.session, principal, showRegister
  app.post "/main/register", app.session, principal, clientAuth, reqGenerator, createUser
  app.get "/main/login", app.session, principal, showLogin
  app.post "/main/login", app.session, clientAuth, handleLogin
  app.post "/main/logout", app.session, userAuth, principal, handleLogout
  app.post "/main/upload", app.session, principal, principalUserOnly, uploadFile  if app.config.uploaddir
  app.get "/:nickname", app.session, principal, reqUser, showStream
  app.get "/:nickname/favorites", app.session, principal, reqUser, showFavorites
  app.get "/:nickname/followers", app.session, principal, reqUser, showFollowers
  app.get "/:nickname/following", app.session, principal, reqUser, showFollowing
  app.get "/:nickname/lists", app.session, principal, reqUser, showLists
  app.get "/:nickname/list/:uuid", app.session, principal, reqUser, showList
  
  # For things that you can only see if you're logged in,
  # we redirect to the login page, then let you go there
  app.get "/main/settings", loginRedirect("/main/settings")
  app.get "/main/account", loginRedirect("/main/account")
  app.get "/:nickname/:type/:uuid", app.session, principal, requestObject, reqUser, userIsAuthor, principalAuthorOrRecipient, showObject
  
  # expose this one file over the web
  app.get "/shared/showdown.js", sharedFile("showdown/src/showdown.js")
  app.get "/shared/underscore.js", sharedFile("underscore/underscore.js")
  app.get "/shared/underscore-min.js", sharedFile("underscore/underscore-min.js")

sharedFile = (fname) ->
  (req, res, next) ->
    res.sendfile path.join(__dirname, "..", "node_modules", fname)

loginRedirect = (rel) ->
  (req, res, next) ->
    res.redirect "/main/login?continue=" + rel

showMain = (req, res, next) ->
  if req.principalUser
    req.log.info
      msg: "Showing inbox for logged-in user"
      user: req.principalUser

    showInbox req, res, next
  else
    req.log.info msg: "Showing welcome page"
    res.render "main",
      page:
        title: "Welcome"


showInbox = (req, res, next) ->
  pump = this
  user = req.principalUser
  profile = req.principal
  getMajor = (callback) ->
    activities = undefined
    Step (->
      user.getMajorInboxStream this
    ), ((err, str) ->
      throw err  if err
      str.getIDs 0, 20, this
    ), ((err, ids) ->
      throw err  if err
      Activity.readArray ids, this
    ), ((err, results) ->
      objects = undefined
      throw err  if err
      activities = results
      objects = _.pluck(activities, "object")
      addLiked profile, objects, @parallel()
      addShared profile, objects, @parallel()
      addLikers profile, objects, @parallel()
      firstFewReplies profile, objects, @parallel()
      firstFewShares profile, objects, @parallel()
    ), (err) ->
      if err
        callback err, null
      else
        callback null, activities


  getMinor = (callback) ->
    Step (->
      user.getMajorInboxStream this
    ), ((err, str) ->
      throw err  if err
      str.getIDs 0, 20, this
    ), ((err, ids) ->
      throw err  if err
      Activity.readArray ids, this
    ), callback

  Step (->
    getMajor @parallel()
    getMinor @parallel()
  ), (err, major, minor) ->
    data = undefined
    if err
      next err
    else
      data =
        major: major
        minor: minor

      data.user = user  if user
      res.render "inbox",
        page:
          title: "Home"

        data: data



showRegister = (req, res, next) ->
  if req.principal
    res.redirect "/"
  else
    res.render "register",
      page:
        title: "Register"


showLogin = (req, res, next) ->
  res.render "login",
    page:
      title: "Login"


handleLogout = (req, res, next) ->
  Step (->
    clearPrincipal req.session, this
  ), ((err) ->
    throw err  if err
    AccessToken.search
      consumer_key: req.client.consumer_key
      username: req.remoteUser.nickname
    , this
  ), ((err, tokens) ->
    i = undefined
    group = @group()
    throw err  if err
    i = 0
    while i < tokens.length
      
      # XXX: keep for auditing?
      tokens[i].del group()
      i++
  ), (err) ->
    if err
      next err
    else
      req.remoteUser = null
      res.json "OK"


showActivity = (req, res, next) ->
  uuid = req.params.uuid
  user = req.user
  Step (->
    Activity.search
      uuid: req.params.uuid
    , this
  ), ((err, activities) ->
    throw err  if err
    next new NoSuchThingError("activity", uuid)  if activities.length is 0
    next new Error("Too many activities with ID = " + req.params.uuid)  if activities.length > 1
    activities[0].expand this
  ), (err, activity) ->
    if err
      next err
    else
      res.render "activity",
        page:
          title: "Welcome"

        data:
          user: req.remoteUser
          activity: activity



getFiltered = (stream, filter, start, end, callback) ->
  filtered = new FilteredStream(stream, filter)
  Step (->
    filtered.getIDs 0, 20, this
  ), ((err, ids) ->
    throw err  if err
    Activity.readAll ids, this
  ), (err, activities) ->
    if err
      callback err, null
    else
      callback null, activities


showStream = (req, res, next) ->
  pump = this
  principal = req.principal
  filter = (if (principal) then ((if (principal.id is req.user.id) then always else recipientsOnly(principal))) else publicOnly)
  getMajor = (callback) ->
    Step (->
      req.user.getMajorOutboxStream this
    ), ((err, str) ->
      throw err  if err
      getFiltered str, filter, 0, 20, @parallel()
    ), callback

  getMinor = (callback) ->
    Step (->
      req.user.getMajorOutboxStream this
    ), ((err, str) ->
      throw err  if err
      getFiltered str, filter, 0, 20, @parallel()
    ), callback

  Step (->
    getMajor @parallel()
    getMinor @parallel()
    addFollowed principal, [req.user.profile], @parallel()
    req.user.profile.expandFeeds @parallel()
  ), (err, major, minor) ->
    if err
      next err
    else
      res.render "user",
        page:
          title: req.user.profile.displayName

        data:
          major: major
          minor: minor
          profile: req.user.profile
          user: req.principalUser



showFavorites = (req, res, next) ->
  pump = this
  principal = req.principal
  filter = (if (principal) then ((if (principal.id is req.user.profile.id) then always else objectRecipientsOnly(principal))) else objectPublicOnly)
  getFavorites = (callback) ->
    Step (->
      req.user.favoritesStream this
    ), ((err, faveStream) ->
      filtered = undefined
      throw err  if err
      filtered = new FilteredStream(faveStream, filter)
      filtered.getObjects 0, 20, this
    ), ((err, refs) ->
      group = @group()
      throw err  if err
      _.each refs, (ref) ->
        ActivityObject.getObject ref.objectType, ref.id, group()

    ), (err, objects) ->
      if err
        callback err, null
      else
        callback null, objects


  Step (->
    getFavorites @parallel()
    addFollowed principal, [req.user.profile], @parallel()
    req.user.profile.expandFeeds @parallel()
  ), (err, objects) ->
    if err
      next err
    else
      res.render "favorites",
        page:
          title: req.user.nickname + " favorites"

        data:
          objects: objects
          user: req.principalUser
          profile: req.user.profile



showFollowers = (req, res, next) ->
  pump = this
  getFollowers = (callback) ->
    followers = undefined
    Step (->
      req.user.getFollowers 0, 20, this
    ), ((err, results) ->
      throw err  if err
      followers = results
      addFollowed req.principal, followers, this
    ), (err) ->
      if err
        callback err, null
      else
        callback null, followers


  Step (->
    getFollowers @parallel()
    addFollowed principal, [req.user.profile], @parallel()
    req.user.profile.expandFeeds @parallel()
  ), (err, followers) ->
    if err
      next err
    else
      res.render "followers",
        page:
          title: req.user.nickname + " followers"

        data:
          people: followers
          user: req.principalUser
          profile: req.user.profile



showFollowing = (req, res, next) ->
  pump = this
  getFollowing = (callback) ->
    following = undefined
    Step (->
      req.user.getFollowing 0, 20, this
    ), ((err, results) ->
      throw err  if err
      following = results
      addFollowed req.principal, following, this
    ), (err) ->
      if err
        callback err, null
      else
        callback null, following


  Step (->
    getFollowing @parallel()
    addFollowed principal, [req.user.profile], @parallel()
    req.user.profile.expandFeeds @parallel()
  ), (err, following) ->
    if err
      next err
    else
      res.render "following",
        page:
          title: req.user.nickname + " following"

        data:
          people: following
          user: req.principalUser
          profile: req.user.profile



handleLogin = (req, res, next) ->
  user = null
  Step (->
    User.checkCredentials req.body.nickname, req.body.password, this
  ), ((err, result) ->
    throw err  if err
    throw new HTTPError("Incorrect username or password", 401)  unless result
    user = result
    setPrincipal req.session, user.profile, this
  ), ((err) ->
    throw err  if err
    user.expand this
  ), ((err) ->
    throw err  if err
    user.profile.expandFeeds this
  ), ((err) ->
    throw err  if err
    req.app.provider.newTokenPair req.client, user, this
  ), (err, pair) ->
    if err
      next err
    else
      user.sanitize()
      user.token = pair.access_token
      user.secret = pair.token_secret
      res.json user


getAllLists = (user, callback) ->
  lists = undefined
  Step (->
    user.getLists "person", this
  ), ((err, str) ->
    throw err  if err
    str.getItems 0, 100, this
  ), ((err, ids) ->
    throw err  if err
    Collection.readAll ids, this
  ), ((err, objs) ->
    group = undefined
    throw err  if err
    lists = objs
    group = @group()
    
    # XXX: Unencapsulate this and do it in 1-2 calls
    _.each lists, (list) ->
      list.expandFeeds group()

  ), (err) ->
    if err
      callback err, null
    else
      callback null, lists


showLists = (req, res, next) ->
  user = req.user
  principal = req.principal
  Step (->
    getAllLists user, @parallel()
    addFollowed principal, [req.user.profile], @parallel()
    req.user.profile.expandFeeds @parallel()
  ), (err, lists) ->
    if err
      next err
    else
      res.render "lists",
        page:
          title: req.user.profile.displayName + " - Lists"

        data:
          user: req.principalUser
          profile: req.user.profile
          lists: lists



showList = (req, res, next) ->
  user = req.user
  principal = req.principal
  getList = (user, uuid, callback) ->
    list = undefined
    Step (->
      Collection.search
        _uuid: req.params.uuid
      , this
    ), ((err, results) ->
      throw err  if err
      throw new HTTPError("Not found", 404)  if results.length is 0
      throw new HTTPError("Too many lists", 500)  if results.length > 1
      list = results[0]
      list.expandFeeds this
    ), ((err) ->
      throw err  if err
      list.getStream this
    ), ((err, str) ->
      throw err  if err
      str.getObjects 0, 100, this
    ), ((err, refs) ->
      group = @group()
      throw err  if err
      _.each refs, (ref) ->
        ActivityObject.getObject ref.objectType, ref.id, group()

    ), (err, objs) ->
      if err
        callback err, null
      else
        list.members.items = objs
        callback null, list


  Step (->
    getAllLists user, @parallel()
    getList req.user, req.param.uuid, @parallel()
    addFollowed principal, [req.user.profile], @parallel()
    req.user.profile.expandFeeds @parallel()
  ), (err, lists, list) ->
    if err
      next err
    else
      res.render "list",
        page:
          title: req.user.profile.displayName + " - Lists"

        data:
          user: req.principalUser
          profile: req.user.profile
          lists: lists
          list: list



uploadFile = (req, res, next) ->
  user = req.principalUser
  uploadDir = req.app.config.uploaddir
  mimeType = undefined
  fileName = undefined
  params = {}
  if req.xhr
    if _.has(req.headers, "x-mime-type")
      mimeType = req.headers["x-mime-type"]
    else
      mimeType = req.uploadMimeType
    fileName = req.uploadFile
    params.title = req.query.title  if _.has(req.query, "title")
    params.description = Scrubber.scrub(req.query.description)  if _.has(req.query, "description")
  else
    mimeType = req.files.qqfile.type
    fileName = req.files.qqfile.path
  req.log.info "Uploading " + fileName + " of type " + mimeType
  Step (->
    saveUpload user, mimeType, fileName, uploadDir, params, this
  ), (err, obj) ->
    data = undefined
    if err
      req.log.error err
      data =
        success: false
        error: "error message to display"

      res.send JSON.stringify(data),
        "Content-Type": "text/plain"
      , 500
    else
      req.log.info "Upload successful"
      obj.sanitize()
      req.log.info obj
      data =
        success: true
        obj: obj

      res.send JSON.stringify(data),
        "Content-Type": "text/plain"
      , 200


userIsAuthor = (req, res, next) ->
  user = req.user
  person = req.person
  type = req.type
  obj = req[type]
  author = obj.author
  if person and author and person.id is author.id
    next()
  else
    next new HTTPError("No " + type + " by " + user.nickname + " with uuid " + obj._uuid, 404)
    return

principalAuthorOrRecipient = (req, res, next) ->
  type = req.type
  obj = req[type]
  user = req.principalUser
  person = req.principal
  if obj and obj.author and person and obj.author.id is person.id
    next()
  else
    Step (->
      Activity.postOf obj, this
    ), ((err, act) ->
      throw err  if err
      act.checkRecipient person, this
    ), (err, isRecipient) ->
      if err
        next err
      else if isRecipient
        next()
      else
        next new HTTPError("Only the author and recipients can view this object.", 403)


showObject = (req, res, next) ->
  type = req.type
  obj = req[type]
  person = req.person
  profile = req.principal
  Step (->
    obj.expandFeeds this
  ), ((err) ->
    throw err  if err
    addLiked profile, [obj], @parallel()
    addShared profile, [obj], @parallel()
    addLikers profile, [obj], @parallel()
    firstFewReplies profile, [obj], @parallel()
    firstFewShares profile, [obj], @parallel()
    addFollowed profile, [obj], @parallel()  if obj.isFollowable()
  ), (err) ->
    title = undefined
    if err
      next err
    else
      if obj.displayName
        title = obj.displayName
      else
        title = type + " by " + person.displayName
      res.render "object",
        page:
          title: title

        data:
          user: req.principalUser
          object: obj



exports.addRoutes = addRoutes
