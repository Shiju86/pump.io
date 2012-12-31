# Dialback verification
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
Step = require("step")
DialbackClient = require("../lib/dialbackclient")
URLMaker = require("../lib/urlmaker").URLMaker
addRoutes = (app) ->
  app.post "/api/dialback", dialback

dialback = (req, res, next) ->
  host = req.body.host
  webfinger = req.body.webfinger
  token = req.body.token
  date = req.body.date
  url = req.body.url
  id = host or webfinger
  ts = undefined
  parts = undefined
  if host and host isnt URLMaker.hostname
    res.status(400).send "Incorrect host"
    return
  else if webfinger
    parts = webfinger.split("@")
    if parts.length isnt 2 or parts[1] isnt URLMaker.hostname
      res.status(400).send "Incorrect host"
      return
  else
    res.status(400).send "No identity"
    return
  unless token
    res.status(400).send "No token"
    return
  unless date
    res.status(400).send "No date"
    return
  ts = Date.parse(date)
  if Math.abs(Date.now() - ts) > 300000 # 5-minute window
    res.status(400).send "Invalid date"
    return
  Step (->
    DialbackClient.isRemembered url, id, token, ts, this
  ), (err, remembered) ->
    if err
      next err
      return
    if remembered
      res.status(200).send "OK"
    else
      res.status(400).send "Not my token"


exports.addRoutes = addRoutes
