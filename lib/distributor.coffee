# distributor.js
#
# Distributes a newly-received activity to recipients
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
_ = require("underscore")
Step = require("step")
databank = require("databank")
OAuth = require("oauth").OAuth
Queue = require("jankyqueue")
cluster = require("cluster")
URLMaker = require("./urlmaker").URLMaker
ActivityObject = require("./model/activityobject").ActivityObject
Collection = require("./model/collection").Collection
User = require("./model/user").User
Person = require("./model/person").Person
Edge = require("./model/edge").Edge
Credentials = require("./model/credentials").Credentials
NoSuchThingError = databank.NoSuchThingError
Distributor = (activity) ->
  @activity = activity
  @delivered = {}
  @expanded = false
  @q = new Queue(Distributor.QUEUE_MAX)

Distributor.QUEUE_MAX = 25
Distributor::distribute = (callback) ->
  dtor = this
  actor = dtor.activity.actor
  recipients = dtor.activity.recipients()
  toRecipients = (cb) ->
    Step (->
      i = undefined
      group = @group()
      i = 0
      while i < recipients.length
        dtor.toRecipient recipients[i], group()
        i++
    ), cb

  toDispatch = (cb) ->
    Step (->
      User.fromPerson actor.id, this
    ), ((err, user) ->
      throw err  if err
      if user
        
        # Send updates
        dtor.outboxUpdates user
        
        # Also inbox!
        dtor.inboxUpdates user
      this null
    ), cb

  Step (->
    unless dtor.expanded
      actor.expandFeeds this
      dtor.expanded = true
    else
      this null
  ), ((err) ->
    throw err  if err
    toRecipients @parallel()
    toDispatch @parallel()
  ), callback

Distributor::toRecipient = (recipient, callback) ->
  dtor = this
  switch recipient.objectType
    when ActivityObject.PERSON
      dtor.toPerson recipient, callback
    when ActivityObject.COLLECTION
      dtor.toCollection recipient, callback
    else
      
      # TODO: log and cry
      return

Distributor::toPerson = (person, callback) ->
  dtor = this
  deliverToPerson = (person, callback) ->
    Step (->
      User.fromPerson person.id, this
    ), (err, user) ->
      recipients = undefined
      throw err  if err
      if user
        user.addToInbox dtor.activity, callback
        dtor.inboxUpdates user
      else
        dtor.toRemotePerson person, callback


  if _(dtor.delivered).has(person.id)
    
    # skip dupes
    callback null
    return
  dtor.delivered[person.id] = 1
  dtor.q.enqueue deliverToPerson, [person], callback

Distributor::toRemotePerson = (person, callback) ->
  dtor = this
  endpoint = undefined
  Step (->
    unless dtor.expanded
      dtor.activity.actor.expandFeeds this
      dtor.expanded = true
    else
      this null
  ), ((err) ->
    throw err  if err
    person.getInbox this
  ), ((err, result) ->
    throw err  if err
    endpoint = result
    Credentials.getFor dtor.activity.actor.id, endpoint, this
  ), ((err, cred) ->
    sanitized = undefined
    oa = undefined
    toSend = undefined
    throw err  if err
    
    # FIXME: use Activity.sanitize() instead
    sanitized = _(dtor.activity).clone()
    delete sanitized.bto  if _(sanitized).has("bto")
    delete sanitized.bcc  if _(sanitized).has("bcc")
    oa = new OAuth(null, null, cred.client_id, cred.client_secret, "1.0", null, "HMAC-SHA1", null, # nonce size; use default
      "User-Agent": "pump.io/0.2.0-alpha.1"
    )
    toSend = JSON.stringify(sanitized)
    oa.post endpoint, null, null, toSend, "application/json", this
  ), (err, body, resp) ->
    if err
      callback err
    else
      callback null


Distributor::toCollection = (collection, callback) ->
  dtor = this
  actor = dtor.activity.actor
  if collection.id is Collection.PUBLIC
    dtor.toFollowers callback
    return
  Step (->
    cb = this
    if actor and actor.objectType is "person" and actor instanceof Person
      actor.followersURL cb
    else
      cb null, null
  ), ((err, url) ->
    throw err  if err
    if url and url is collection.id
      dtor.toFollowers callback
    else
      
      # Usually stored by reference, so get the full object
      ActivityObject.getObject collection.objectType, collection.id, this
  ), ((err, result) ->
    if err and err.name is "NoSuchThingError"
      callback null
    else if err
      throw err
    else
      
      # XXX: assigning to function param
      collection = result
      Collection.isList collection, this
  ), (err, isList) ->
    if err
      callback err
    else if isList and (collection.author.id is actor.id)
      dtor.toList collection, callback
    else
      
      # XXX: log, bemoan
      callback null


Distributor::toFollowers = (callback) ->
  dtor = this
  
  # XXX: use followers stream instead
  Step (->
    Edge.search
      "to.id": dtor.activity.actor.id
    , this
  ), ((err, edges) ->
    i = undefined
    group = @group()
    throw err  if err
    i = 0
    while i < edges.length
      Person.get edges[i].from.id, group()
      i++
  ), ((err, people) ->
    throw err  if err
    i = undefined
    group = @group()
    i = 0
    while i < people.length
      dtor.toPerson people[i], group()
      i++
  ), callback


# Send a message to the dispatch process
# to note an update of this feed with this activity
Distributor::sendUpdate = (url) ->
  dtor = this
  if cluster.isWorker
    cluster.worker.send
      cmd: "update"
      url: url
      activity: dtor.activity

  return


# Send updates for each applicable inbox feed
# for this user. Covers main inbox, major/minor inbox,
# direct inbox, and major/minor direct inbox 
Distributor::inboxUpdates = (user) ->
  dtor = this
  isDirectTo = (user) ->
    recipients = directRecipients(dtor.activity)
    _.any recipients, (item) ->
      item.id is user.profile.id and item.objectType is user.profile.objectType


  directRecipients = (act) ->
    props = ["to", "bto"]
    recipients = []
    props.forEach (prop) ->
      recipients = recipients.concat(act[prop])  if _(act).has(prop) and _(act[prop]).isArray()

    
    # XXX: ensure uniqueness
    recipients

  dtor.sendUpdate URLMaker.makeURL("/api/user/" + user.nickname + "/inbox")
  if dtor.activity.isMajor()
    dtor.sendUpdate URLMaker.makeURL("/api/user/" + user.nickname + "/inbox/major")
  else
    dtor.sendUpdate URLMaker.makeURL("/api/user/" + user.nickname + "/inbox/minor")
  if isDirectTo(user)
    dtor.sendUpdate URLMaker.makeURL("/api/user/" + user.nickname + "/inbox/direct")
    if dtor.activity.isMajor()
      dtor.sendUpdate URLMaker.makeURL("/api/user/" + user.nickname + "/inbox/direct/major")
    else
      dtor.sendUpdate URLMaker.makeURL("/api/user/" + user.nickname + "/inbox/direct/minor")


# Send updates for each applicable outbox feed
# for this user. Covers main feed, major/minor feed
Distributor::outboxUpdates = (user) ->
  dtor = this
  dtor.sendUpdate URLMaker.makeURL("/api/user/" + user.nickname + "/feed")
  if dtor.activity.isMajor()
    dtor.sendUpdate URLMaker.makeURL("/api/user/" + user.nickname + "/feed/major")
  else
    dtor.sendUpdate URLMaker.makeURL("/api/user/" + user.nickname + "/feed/minor")

module.exports = Distributor
