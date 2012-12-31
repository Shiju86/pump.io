# pump.js
#
# Entrypoint for the pump.io client UI
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

# Make sure this exists
window.Pump = {}  unless window.Pump
((_, $, Backbone, Pump) ->
  
  # This is overwritten by inline script in layout.utml
  Pump.config = {}
  
  # Main entry point
  $(document).ready ->
    
    # XXX: set up initial models
    
    # Set up router
    Pump.router = new Pump.Router()
    
    # Set up initial view
    Pump.body = new Pump.BodyView(el: $("body"))
    Pump.body.nav = new Pump.AnonymousNav(el: ".navbar-inner .container")
    
    # XXX: Make this more complete
    if $("#content #login").length > 0
      Pump.body.content = new Pump.LoginContent()
    else if $("#content #registration").length > 0
      Pump.body.content = new Pump.RegisterContent()
    else if $("#content #user").length > 0
      Pump.body.content = new Pump.UserPageContent({})
    else Pump.body.content = new Pump.InboxContent({})  if $("#content #inbox").length > 0
    $("abbr.easydate").easydate()
    Backbone.history.start
      pushState: true
      silent: true

    Pump.setupWysiHTML5()
    
    # Refresh the streams automatically every 60 seconds
    # This is a fallback in case something gets lost in the
    # SockJS conversation
    Pump.refreshStreamsID = setInterval(Pump.refreshStreams, 60000)
    
    # Connect to current server
    Pump.setupSocket()  if Pump.config.sockjs
    Pump.setupInfiniteScroll()
    
    # Check if we have stored OAuth credentials
    Pump.ensureCred (err, cred) ->
      user = undefined
      nickname = undefined
      pair = undefined
      major = undefined
      minor = undefined
      if err
        Pump.error err.message
        return
      nickname = Pump.getNickname()
      if nickname
        user = new Pump.User(nickname: nickname)
        major = user.majorDirectInbox
        minor = user.minorDirectInbox
        Pump.fetchObjects [user, major, minor], (err, objs) ->
          sp = undefined
          continueTo = undefined
          if err
            Pump.error err
            return
          Pump.currentUser = user
          Pump.body.nav = new Pump.UserNav(
            el: ".navbar-inner .container"
            model: user
            data:
              messages: major
              notifications: minor
          )
          Pump.body.nav.render()
          
          # If we're on the login page, and there's a current
          # user, redirect to the actual page
          switch window.location.pathname
            when "/main/login"
              Pump.body.content = new Pump.LoginContent()
              continueTo = Pump.getContinueTo()
              Pump.router.navigate continueTo, true
            when "/"
              Pump.router.home()



  
  # When errors happen, and you don't know what to do with them,
  # send them here and I'll figure it out.
  Pump.error = (err) ->
    console.log err

  
  # Given a relative URL like /main/register, make a fully-qualified
  # URL on the current server
  Pump.fullURL = (url) ->
    here = window.location
    if url.indexOf(":") is -1
      if url.substr(0, 1) is "/"
        url = here.protocol + "//" + here.host + url
      else
        url = here.href.substr(0, here.href.lastIndexOf("/") + 1) + url
    url

  
  # Add some OAuth magic to the arguments for a $.ajax() call
  Pump.oauthify = (options) ->
    options.url = Pump.fullURL(options.url)
    message =
      action: options.url
      method: options.type
      parameters: [["oauth_version", "1.0"], ["oauth_consumer_key", options.consumerKey]]

    message.parameters.push ["oauth_token", options.token]  if options.token
    OAuth.setTimestampAndNonce message
    OAuth.SignatureMethod.sign message,
      consumerSecret: options.consumerSecret
      tokenSecret: options.tokenSecret

    header = OAuth.getAuthorizationHeader("OAuth", message.parameters)
    options.headers = Authorization: header
    options

  Pump.fetchObjects = (orig, callback) ->
    fetched = 0
    objs = (if (orig.length) > 0 then orig.slice(0) else []) # make a dupe in case arg is changed
    count = objs.length
    done = false
    onSuccess = ->
      unless done
        fetched++
        if fetched >= count
          done = true
          callback null, objs

    onError = (xhr, status, thrown) ->
      unless done
        done = true
        if thrown
          callback thrown, null
        else
          callback new Error(status), null

    _.each objs, (obj) ->
      try
        obj.fetch
          success: onSuccess
          error: onError

      catch e
        onError null, null, e


  
  # Not the most lovely, but it works
  # XXX: change this to use UTML templating instead
  Pump.wysihtml5Tmpl = emphasis: (locale) ->
    "<li>" + "<div class='btn-group'>" + "<a class='btn' data-wysihtml5-command='bold' title='" + locale.emphasis.bold + "'><i class='icon-bold'></i></a>" + "<a class='btn' data-wysihtml5-command='italic' title='" + locale.emphasis.italic + "'><i class='icon-italic'></i></a>" + "<a class='btn' data-wysihtml5-command='underline' title='" + locale.emphasis.underline + "'>_</a>" + "</div>" + "</li>"

  
  # Most long-form descriptions and notes use this lib for editing
  Pump.setupWysiHTML5 = ->
    
    # Set wysiwyg defaults
    $.fn.wysihtml5.defaultOptions["font-styles"] = false
    $.fn.wysihtml5.defaultOptions["image"] = false
    $.fn.wysihtml5.defaultOptions["customTemplates"] = Pump.wysihtml5Tmpl

  
  # Turn the querystring into an object
  Pump.searchParams = (str) ->
    params = {}
    pl = /\+/g
    decode = (s) ->
      decodeURIComponent s.replace(pl, " ")

    pairs = undefined
    str = window.location.search  unless str
    pairs = str.substr(1).split("&")
    _.each pairs, (pairStr) ->
      pair = pairStr.split("=", 2)
      key = decode(pair[0])
      value = (if (pair.length > 1) then decode(pair[1]) else null)
      params[key] = value

    params

  
  # Get the "continue" param
  Pump.getContinueTo = ->
    sp = Pump.searchParams()
    continueTo = (if (_.has(sp, "continue")) then sp["continue"] else null)
    if continueTo and continueTo.length > 0 and continueTo[0] is "/"
      continueTo
    else
      ""

  
  # We clear out cached stuff when login state changes
  Pump.clearCaches = ->
    Pump.Model.clearCache()
    Pump.Collection.clearCache()
    Pump.User.clearCache()

  Pump.ajax = (options) ->
    Pump.ensureCred (err, cred) ->
      pair = undefined
      if err
        Pump.error "Couldn't get OAuth credentials. :("
      else
        options.consumerKey = cred.clientID
        options.consumerSecret = cred.clientSecret
        pair = Pump.getUserCred()
        if pair
          options.token = pair.token
          options.tokenSecret = pair.secret
        options = Pump.oauthify(options)
        $.ajax options


  Pump.setupInfiniteScroll = ->
    didScroll = false
    
    # scroll fires too fast, so just use the handler
    # to set a flag, and check that flag with an interval
    
    # From http://ejohn.org/blog/learning-from-twitter/
    $(window).scroll ->
      didScroll = true

    setInterval (->
      streams = undefined
      if didScroll
        didScroll = false
        if $(window).scrollTop() >= $(document).height() - $(window).height() - 10
          streams = Pump.getStreams()
          streams.major.getNext()  if streams.major and streams.major.nextLink
    ), 250
) window._, window.$, window.Backbone, window.Pump
