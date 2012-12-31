# pump/auth.js
#
# OAuth authentication mechanism for the pump.io client UI
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
  Pump.currentUser = null # XXX: load from server...?
  Pump.clientID = null
  Pump.clientSecret = null
  Pump.nickname = null
  Pump.token = null
  Pump.secret = null
  Pump.credReq = null
  Pump.setNickname = (userNickname) ->
    Pump.nickname = userNickname
    localStorage["cred:nickname"] = userNickname  if localStorage

  Pump.getNickname = ->
    if Pump.nickname
      Pump.nickname
    else if localStorage
      localStorage["cred:nickname"]
    else
      null

  Pump.clearNickname = ->
    Pump.nickname = null
    delete localStorage["cred:nickname"]  if localStorage

  Pump.getCred = ->
    if Pump.clientID
      clientID: Pump.clientID
      clientSecret: Pump.clientSecret
    else if localStorage
      Pump.clientID = localStorage["cred:clientID"]
      Pump.clientSecret = localStorage["cred:clientSecret"]
      if Pump.clientID
        clientID: Pump.clientID
        clientSecret: Pump.clientSecret
      else
        null
    else
      null

  Pump.getUserCred = (nickname) ->
    if Pump.token
      token: Pump.token
      secret: Pump.secret
    else if localStorage
      Pump.token = localStorage["cred:token"]
      Pump.secret = localStorage["cred:secret"]
      if Pump.token
        token: Pump.token
        secret: Pump.secret
      else
        null
    else
      null

  Pump.setUserCred = (userToken, userSecret) ->
    Pump.token = userToken
    Pump.secret = userSecret
    if localStorage
      localStorage["cred:token"] = userToken
      localStorage["cred:secret"] = userSecret
    return

  Pump.clearUserCred = ->
    Pump.token = null
    Pump.secret = null
    if localStorage
      delete localStorage["cred:token"]

      delete localStorage["cred:secret"]
    return

  Pump.ensureCred = (callback) ->
    cred = Pump.getCred()
    if cred
      callback null, cred
    else if Pump.credReq
      Pump.credReq.success (data) ->
        callback null,
          clientID: data.client_id
          clientSecret: data.client_secret


      Pump.credReq.error ->
        callback new Error("error getting credentials"), null

    else
      Pump.credReq = $.post("/api/client/register",
        type: "client_associate"
        application_name: Pump.config.site + " Web"
        application_type: "web"
      , (data) ->
        Pump.credReq = null
        Pump.clientID = data.client_id
        Pump.clientSecret = data.client_secret
        if localStorage
          localStorage["cred:clientID"] = Pump.clientID
          localStorage["cred:clientSecret"] = Pump.clientSecret
        callback null,
          clientID: Pump.clientID
          clientSecret: Pump.clientSecret

      , "json")
      Pump.credReq.error ->
        callback new Error("error getting credentials"), null

) window._, window.$, window.Backbone, window.Pump
