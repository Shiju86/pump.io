# dispatch.js
#
# Dispatches messages between workers
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
cluster = require("cluster")
_ = require("underscore")
Dispatch =
  log: null
  start: (log) ->
    dsp = this
    dsp.log = log.child(component: "dispatch")  if log
    
    # Listen to existing workers
    _.each cluster.workers, (worker, id) ->
      dsp.setupWorker worker

    
    # If new workers fork, listen to those, too
    cluster.on "fork", (worker) ->
      dsp.setupWorker worker

    dsp.log.info "Dispatch setup complete."  if dsp.log

  setupWorker: (worker) ->
    dsp = this
    worker.on "message", (msg) ->
      switch msg.cmd
        when "follow"
          dsp.addFollower msg.url, worker.id
        when "unfollow"
          dsp.removeFollower msg.url, worker.id
        when "update"
          dsp.updateFollowers msg.url, msg.activity
        else


  followers: {}
  addFollower: (url, id) ->
    dsp = this
    dsp.followers[url] = []  unless _.has(dsp.followers, url)
    unless _.contains(dsp.followers[url], id)
      if dsp.log
        dsp.log.info
          url: url
          id: id
        , "Adding follower"
      dsp.followers[url].push id

  removeFollower: (url, id) ->
    dsp = this
    idx = undefined
    if _.has(dsp.followers, url)
      idx = dsp.followers[url].indexOf(id)
      if idx isnt -1
        if dsp.log
          dsp.log.info
            url: url
            id: id
          , "Removing follower"
        dsp.followers[url].splice idx, 1

  updateFollowers: (url, activity) ->
    dsp = this
    if _.has(dsp.followers, url)
      _.each dsp.followers[url], (id) ->
        worker = cluster.workers[id]
        
        # XXX: clear out old subscriptions
        if worker
          if dsp.log
            dsp.log.info
              url: url
              activity: activity.id
              id: id
            , "Dispatching to worker."
          worker.send
            cmd: "update"
            url: url
            activity: activity



module.exports = Dispatch
