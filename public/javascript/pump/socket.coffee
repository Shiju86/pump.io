# pump/socket.js
#
# Socket module for the pump.io client UI
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
  Pump.getStreams = ->
    content = undefined
    nav = undefined
    streams = {}
    if Pump.body
      if Pump.body.content
        if Pump.body.content.userContent
          if Pump.body.content.userContent.listContent
            content = Pump.body.content.userContent.listContent
          else
            content = Pump.body.content.userContent
        else
          content = Pump.body.content
      nav = Pump.body.nav  if Pump.body.nav
    if content
      streams.major = content.majorStreamView.collection  if content.majorStreamView
      streams.minor = content.minorStreamView.collection  if content.minorStreamView
    if nav
      streams.messages = nav.majorStreamView.collection  if nav.majorStreamView
      streams.notifications = nav.minorStreamView.collection  if nav.minorStreamView
    streams

  
  # Refreshes the current visible streams
  Pump.refreshStreams = ->
    streams = Pump.getStreams()
    _.each streams, (stream, name) ->
      stream.getPrev()


  Pump.updateStream = (url, activity) ->
    streams = Pump.getStreams()
    target = _.find(streams, (stream) ->
      stream.url is url
    )
    act = undefined
    if target
      act = Pump.Activity.unique(activity)
      target.unshift act

  
  # When we get a challenge from the socket server,
  # We prepare an OAuth request and send it
  Pump.riseToChallenge = (url, method) ->
    message =
      action: url
      method: method
      parameters: [["oauth_version", "1.0"]]

    Pump.ensureCred (err, cred) ->
      pair = undefined
      secrets = undefined
      if err
        Pump.error "Error getting OAuth credentials."
        return
      message.parameters.push ["oauth_consumer_key", cred.clientID]
      secrets = consumerSecret: cred.clientSecret
      pair = Pump.getUserCred()
      if pair
        message.parameters.push ["oauth_token", pair.token]
        secrets.tokenSecret = pair.secret
      OAuth.setTimestampAndNonce message
      OAuth.SignatureMethod.sign message, secrets
      Pump.socket.send JSON.stringify(
        cmd: "rise"
        message: message
      )


  
  # Our socket.io socket
  Pump.socket = null
  Pump.setupSocket = ->
    here = window.location
    sock = undefined
    if Pump.socket
      Pump.socket.close()
      Pump.socket = null
    sock = new SockJS(here.protocol + "//" + here.host + "/main/realtime/sockjs")
    sock.onopen = ->
      Pump.socket = sock
      Pump.followStreams()

    sock.onmessage = (e) ->
      data = JSON.parse(e.data)
      switch data.cmd
        when "update"
          Pump.updateStream data.url, data.activity
        when "challenge"
          Pump.riseToChallenge data.url, data.method

    sock.onclose = ->
      
      # XXX: reconnect?
      Pump.socket = null

  Pump.followStreams = ->
    return  unless Pump.config.sockjs
    return  unless Pump.socket
    streams = Pump.getStreams()
    _.each streams, (stream, name) ->
      Pump.socket.send JSON.stringify(
        cmd: "follow"
        url: stream.url
      )


  Pump.unfollowStreams = ->
    return  unless Pump.config.sockjs
    return  unless Pump.socket
    streams = Pump.getStreams()
    _.each streams, (stream, name) ->
      Pump.socket.send JSON.stringify(
        cmd: "unfollow"
        url: stream.url
      )

) window._, window.$, window.Backbone, window.Pump
