# pump/view.js
#
# Views for the pump.io client UI
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

# XXX: this needs to be broken up into 3-4 smaller modules
((_, $, Backbone, Pump) ->
  Pump.templates = {}
  Pump.TemplateError = (template, data, err) ->
    Error.captureStackTrace this, Pump.TemplateError
    @name = "TemplateError"
    @template = template
    @data = data
    @wrapped = err
    @message = ((if (_.has(template, "templateName")) then template.templateName else "unknown-template")) + ": " + err.message

  Pump.TemplateError:: = new Error()
  Pump.TemplateError::constructor = Pump.TemplateError
  Pump.TemplateView = Backbone.View.extend(
    initialize: (options) ->
      view = this
      if _.has(view, "model") and _.isObject(view.model)
        view.listenTo view.model, "change", (options) ->
          
          # When a change has happened, re-render
          view.render()

        view.listenTo view.model, "destroy", (options) ->
          
          # When a change has happened, re-render
          view.remove()

      else if _.has(view, "collection") and _.isObject(view.collection)
        view.listenTo view.collection, "add", (model, collection, options) ->
          view.showAdded model

        view.listenTo view.collection, "remove", (model, collection, options) ->
          view.showRemoved model

        view.listenTo view.collection, "reset", (collection, options) ->
          
          # When a change has happened, re-render
          view.render()

        view.listenTo view.collection, "sort", (collection, options) ->
          
          # When a change has happened, re-render
          view.render()


    setElement: (element, delegate) ->
      Backbone.View::setElement.apply this, arguments_
      if element
        @ready()
        @trigger "ready"

    templateName: null
    parts: null
    subs: {}
    ready: ->
      
      # setup subViews
      @setupSubs()

    setupSubs: ->
      view = this
      data = view.options.data
      subs = view.subs
      return  unless subs
      _.each subs, (def, selector) ->
        $el = view.$(selector)
        options = undefined
        sub = undefined
        id = undefined
        if def.attr and view[def.attr]
          view[def.attr].setElement $el
          return
        if def.idAttr and view.collection
          view[def.map] = {}  unless view[def.map]  if def.map
          $el.each (i, el) ->
            id = $(el).attr(def.idAttr)
            options = el: el
            return  unless id
            options.model = view.collection.get(id)
            return  unless options.model
            sub = new Pump[def.subView](options)
            view[def.map][id] = sub  if def.map

          return
        options = el: $el
        if def.subOptions
          options.model = data[def.subOptions.model]  if def.subOptions.model
          options.collection = data[def.subOptions.collection]  if def.subOptions.collection
          if def.subOptions.data
            options.data = {}
            _.each def.subOptions.data, (item) ->
              options.data[item] = data[item]

        sub = new Pump[def.subView](options)
        view[def.attr] = sub  if def.attr


    render: ->
      view = this
      getTemplate = (name, cb) ->
        url = undefined
        if _.has(Pump.templates, name)
          cb null, Pump.templates[name]
        else
          $.get "/template/" + name + ".utml", (data) ->
            f = undefined
            try
              f = _.template(data)
              f.templateName = name
              Pump.templates[name] = f
            catch err
              cb err, null
              return
            cb null, f


      getTemplateSync = (name) ->
        f = undefined
        data = undefined
        res = undefined
        if _.has(Pump.templates, name)
          Pump.templates[name]
        else
          res = $.ajax(
            url: "/template/" + name + ".utml"
            async: false
          )
          if res.readyState is 4 and ((res.status >= 200 and res.status < 300) or res.status is 304)
            data = res.responseText
            f = _.template(data)
            f.templateName = name
            Pump.templates[name] = f
          f

      runTemplate = (template, data, cb) ->
        html = undefined
        try
          html = template(data)
        catch err
          cb new Pump.TemplateError(template, data, err), null
          return
        cb null, html

      setOutput = (err, html) ->
        if err
          Pump.error err
        else
          
          # Triggers "ready"
          view.setHTML html
          
          # Update relative to the new code view
          view.$("abbr.easydate").easydate()

      main =
        config: Pump.config
        data: {}
        template: {}
        page: {}

      pc = undefined
      modelName = view.modelName or view.options.modelName or "model"
      partials = {}
      cnt = undefined
      if view.collection
        main.data[modelName] = view.collection.toJSON()
      else main.data[modelName] = (if (not view.model) then {} else ((if (view.model.toJSON) then view.model.toJSON() else view.model)))  if view.model
      if _.has(view.options, "data")
        _.each view.options.data, (obj, name) ->
          if obj.toJSON
            main.data[name] = obj.toJSON()
          else
            main.data[name] = obj

      main.data.user = Pump.currentUser.toJSON()  if Pump.currentUser and not _.has(main.data, "user")
      main.partial = (name, locals) ->
        template = undefined
        scoped = undefined
        if locals
          scoped = _.clone(locals)
          _.extend scoped, main
        else
          scoped = main
        unless _.has(partials, name)
          console.log "Didn't preload template " + name + " so fetching sync"
          
          # XXX: Put partials in the parts array of the
          # view to avoid this shameful sync call
          partials[name] = getTemplateSync(name)
        template = partials[name]
        throw new Error("No template for " + name)  unless template
        template scoped

      
      # XXX: set main.page.title
      
      # If there are sub-parts, we do them in parallel then
      # do the main one. Note: only one level.
      if view.parts
        pc = 0
        cnt = _.keys(view.parts).length
        _.each view.parts, (templateName) ->
          getTemplate templateName, (err, template) ->
            if err
              Pump.error err
            else
              pc++
              partials[templateName] = template
              if pc >= cnt
                getTemplate view.templateName, (err, template) ->
                  runTemplate template, main, setOutput



      else
        getTemplate view.templateName, (err, template) ->
          runTemplate template, main, setOutput

      this

    stopSpin: ->
      @$(":submit").prop("disabled", false).spin false

    startSpin: ->
      @$(":submit").prop("disabled", true).spin true

    showAlert: (msg, type) ->
      view = this
      view.$(".alert").remove()  if view.$(".alert").length > 0
      type = type or "error"
      view.$("legend").after "<div class=\"alert alert-" + type + "\">" + "<a class=\"close\" data-dismiss=\"alert\" href=\"#\">&times;</a>" + "<p class=\"alert-message\">" + msg + "</p>" + "</div>"
      view.$(".alert").alert()

    showError: (msg) ->
      @showAlert msg, "error"

    showSuccess: (msg) ->
      @showAlert msg, "success"

    setHTML: (html) ->
      view = this
      $old = view.$el
      $new = $(html).first()
      $old.replaceWith $new
      view.setElement $new
      $old = null

    showAdded: (model) ->
      view = this
      id = model.get("id")
      subs = view.subs
      aview = undefined
      def = undefined
      selector = undefined
      
      # Strange!
      return  unless subs
      return  unless view.collection
      
      # Find the first def and selector with a map
      _.each subs, (subDef, subSelector) ->
        if subDef.map
          def = subDef
          selector = subSelector

      return  unless def
      view[def.map] = {}  unless view[def.map]
      
      # If we already have it, skip
      return  if _.has(view[def.map], id)
      
      # Show the new item
      aview = new Pump[def.subView](model: model)
      
      # Stash the view
      view[def.map][model.id] = aview
      
      # When it's rendered, stick it where it goes
      aview.on "ready", ->
        idx = undefined
        $el = view.$(selector)
        aview.$el.hide()
        idx = view.collection.indexOf(model)
        if idx <= 0
          view.$el.prepend aview.$el
        else if idx >= $el.length
          view.$el.append aview.$el
        else
          aview.$el.insertBefore $el[idx]
        aview.$el.fadeIn "slow"

      aview.render()

    showRemoved: (model) ->
      view = this
      id = model.get("id")
      aview = undefined
      def = undefined
      selector = undefined
      subs = view.subs
      
      # Possible but not likely
      return  unless subs
      return  unless view.collection
      
      # Find the first def and selector with a map
      _.each subs, (subDef, subSelector) ->
        if subDef.map
          def = subDef
          selector = subSelector

      return  unless def
      view[def.map] = {}  unless view[def.map]
      return  unless _.has(view[def.map], id)
      
      # Remove it from the DOM
      view[def.map][id].remove()
      
      # delete that view from our map
      delete view[def.map][id]
  )
  Pump.AnonymousNav = Pump.TemplateView.extend(
    tagName: "div"
    className: "container"
    templateName: "nav-anonymous"
  )
  Pump.UserNav = Pump.TemplateView.extend(
    tagName: "div"
    className: "container"
    modelName: "user"
    templateName: "nav-loggedin"
    parts: ["messages", "notifications"]
    subs:
      "#messages":
        attr: "majorStreamView"
        subView: "MessagesView"
        subOptions:
          collection: "messages"

      "#notifications":
        attr: "minorStreamView"
        subView: "NotificationsView"
        subOptions:
          collection: "notifications"

    events:
      "click #logout": "logout"
      "click #post-note-button": "postNoteModal"
      "click #post-picture-button": "postPictureModal"
      "click #profile-dropdown": "profileDropdown"

    postNoteModal: ->
      profile = Pump.currentUser.profile
      lists = profile.lists
      following = profile.following
      Pump.fetchObjects [lists, following], (err, objs) ->
        Pump.showModal Pump.PostNoteModal,
          data:
            user: Pump.currentUser
            lists: lists
            following: following


      false

    postPictureModal: ->
      profile = Pump.currentUser.profile
      lists = profile.lists
      following = profile.following
      Pump.fetchObjects [lists, following], (err, objs) ->
        Pump.showModal Pump.PostPictureModal,
          data:
            user: Pump.currentUser
            lists: lists
            following: following


      false

    profileDropdown: ->
      $("#profile-dropdown").dropdown()

    logout: ->
      view = this
      options = undefined
      onSuccess = (data, textStatus, jqXHR) ->
        an = undefined
        Pump.currentUser = null
        Pump.clearNickname()
        Pump.clearUserCred()
        Pump.clearCaches()
        an = new Pump.AnonymousNav(el: ".navbar-inner .container")
        an.render()
        
        # Request a new challenge
        Pump.setupSocket()  if Pump.config.sockjs
        if window.location.pathname is "/"
          
          # If already home, reload to show main page
          Pump.router.home()
        else
          
          # Go home
          Pump.router.navigate "/", true

      onError = (jqXHR, textStatus, errorThrown) ->
        showError errorThrown

      showError = (msg) ->
        Pump.error msg

      options =
        contentType: "application/json"
        data: ""
        dataType: "json"
        type: "POST"
        url: "/main/logout"
        success: onSuccess
        error: onError

      Pump.ajax options
  )
  Pump.MessagesView = Pump.TemplateView.extend(
    templateName: "messages"
    modelName: "messages"
  )
  Pump.NotificationsView = Pump.TemplateView.extend(
    templateName: "notifications"
    modelName: "notifications"
  )
  Pump.ContentView = Pump.TemplateView.extend(
    addMajorActivity: (act) ->

    
    # By default, do nothing
    addMinorActivity: (act) ->
  )
  
  # By default, do nothing
  Pump.MainContent = Pump.ContentView.extend(templateName: "main")
  Pump.LoginContent = Pump.ContentView.extend(
    templateName: "login"
    events:
      "submit #login": "doLogin"

    doLogin: ->
      view = this
      params =
        nickname: view.$("#login input[name=\"nickname\"]").val()
        password: view.$("#login input[name=\"password\"]").val()

      options = undefined
      continueTo = Pump.getContinueTo()
      NICKNAME_RE = /^[a-zA-Z0-9\-_.]{1,64}$/
      onSuccess = (data, textStatus, jqXHR) ->
        objs = undefined
        Pump.setNickname data.nickname
        Pump.setUserCred data.token, data.secret
        Pump.clearCaches()
        Pump.currentUser = Pump.User.unique(data)
        objs = [Pump.currentUser, Pump.currentUser.majorDirectInbox, Pump.currentUser.minorDirectInbox]
        Pump.fetchObjects objs, (err, objs) ->
          Pump.body.nav = new Pump.UserNav(
            el: ".navbar-inner .container"
            model: Pump.currentUser
            data:
              messages: Pump.currentUser.majorDirectInbox
              notifications: Pump.currentUser.minorDirectInbox
          )
          Pump.body.nav.render()

        
        # Request a new challenge
        Pump.setupSocket()  if Pump.config.sockjs
        
        # XXX: reload current data
        view.stopSpin()
        Pump.router.navigate continueTo, true

      onError = (jqXHR, textStatus, errorThrown) ->
        type = undefined
        response = undefined
        view.stopSpin()
        type = jqXHR.getResponseHeader("Content-Type")
        if type and type.indexOf("application/json") isnt -1
          response = JSON.parse(jqXHR.responseText)
          view.showError response.error
        else
          view.showError errorThrown

      view.startSpin()
      options =
        contentType: "application/json"
        data: JSON.stringify(params)
        dataType: "json"
        type: "POST"
        url: "/main/login"
        success: onSuccess
        error: onError

      Pump.ajax options
      false
  )
  Pump.RegisterContent = Pump.ContentView.extend(
    templateName: "register"
    events:
      "submit #registration": "register"

    register: ->
      view = this
      params =
        nickname: view.$("#registration input[name=\"nickname\"]").val()
        password: view.$("#registration input[name=\"password\"]").val()

      repeat = view.$("#registration input[name=\"repeat\"]").val()
      email = (if (Pump.config.requireEmail) then view.$("#registration input[name=\"email\"]").val() else null)
      options = undefined
      NICKNAME_RE = /^[a-zA-Z0-9\-_.]{1,64}$/
      onSuccess = (data, textStatus, jqXHR) ->
        objs = undefined
        Pump.setNickname data.nickname
        Pump.setUserCred data.token, data.secret
        Pump.clearCaches()
        Pump.currentUser = Pump.User.unique(data)
        
        # Request a new challenge
        Pump.setupSocket()  if Pump.config.sockjs
        objs = [Pump.currentUser, Pump.currentUser.majorDirectInbox, Pump.currentUser.minorDirectInbox]
        Pump.fetchObjects objs, (err, objs) ->
          Pump.body.nav = new Pump.UserNav(
            el: ".navbar-inner .container"
            model: Pump.currentUser
            data:
              messages: Pump.currentUser.majorDirectInbox
              notifications: Pump.currentUser.minorDirectInbox
          )
          Pump.body.nav.render()

        Pump.body.nav.render()
        
        # Leave disabled
        view.stopSpin()
        
        # XXX: one-time on-boarding page
        Pump.router.navigate "", true

      onError = (jqXHR, textStatus, errorThrown) ->
        type = undefined
        response = undefined
        view.stopSpin()
        type = jqXHR.getResponseHeader("Content-Type")
        if type and type.indexOf("application/json") isnt -1
          response = JSON.parse(jqXHR.responseText)
          view.showError response.error
        else
          view.showError errorThrown

      if params.password isnt repeat
        view.showError "Passwords don't match."
      else unless NICKNAME_RE.test(params.nickname)
        view.showError "Nicknames have to be a combination of 1-64 letters or numbers and ., - or _."
      else if params.password.length < 8
        view.showError "Password must be 8 chars or more."
      else if /^[a-z]+$/.test(params.password.toLowerCase()) or /^[0-9]+$/.test(params.password)
        view.showError "Passwords have to have at least one letter and one number."
      else if Pump.config.requireEmail and (not email or email.length is 0)
        view.showError "Email address required."
      else
        params.email = email  if Pump.config.requireEmail
        view.startSpin()
        options =
          contentType: "application/json"
          data: JSON.stringify(params)
          dataType: "json"
          type: "POST"
          url: "/main/register"
          success: onSuccess
          error: onError

        Pump.ensureCred (err, cred) ->
          if err
            view.showError "Couldn't get OAuth credentials. :("
          else
            options.consumerKey = cred.clientID
            options.consumerSecret = cred.clientSecret
            options = Pump.oauthify(options)
            $.ajax options

      false
  )
  Pump.UserPageContent = Pump.ContentView.extend(
    templateName: "user"
    parts: ["profile-block", "user-content-activities", "major-stream-headless", "minor-stream-headless", "major-activity-headless", "minor-activity-headless", "responses", "reply", "profile-responses", "activity-object-list", "activity-object-collection"]
    addMajorActivity: (act) ->
      view = this
      profile = @options.data.profile
      return  if not profile or act.actor.id isnt profile.get("id")
      view.userContent.majorStreamView.showAdded act

    addMinorActivity: (act) ->
      view = this
      profile = @options.data.profile
      return  if not profile or act.actor.id isnt profile.get("id")
      view.userContent.minorStreamView.showAdded act

    subs:
      "#profile-block":
        attr: "profileBlock"
        subView: "ProfileBlock"
        subOptions:
          model: "profile"

      "#user-content-activities":
        attr: "userContent"
        subView: "ActivitiesUserContent"
        subOptions:
          data: ["major", "minor"]
  )
  Pump.ActivitiesUserContent = Pump.TemplateView.extend(
    templateName: "user-content-activities"
    parts: ["major-stream-headless", "minor-stream-headless", "major-activity-headless", "minor-activity-headless", "responses", "reply", "profile-responses", "activity-object-list", "activity-object-collection"]
    subs:
      "#major-stream":
        attr: "majorStreamView"
        subView: "MajorStreamHeadlessView"
        subOptions:
          collection: "major"

      "#minor-stream":
        attr: "minorStreamView"
        subView: "MinorStreamHeadlessView"
        subOptions:
          collection: "minor"
  )
  Pump.MajorStreamHeadlessView = Pump.TemplateView.extend(
    templateName: "major-stream-headless"
    modelName: "major"
    parts: ["major-activity-headless", "responses", "reply", "activity-object-list", "activity-object-collection"]
    subs:
      ".activity.major":
        map: "activities"
        subView: "MajorActivityHeadlessView"
        idAttr: "data-activity-id"
  )
  Pump.MinorStreamHeadlessView = Pump.TemplateView.extend(
    templateName: "minor-stream-headless"
    modelName: "minor"
    parts: ["minor-activity-headless"]
    subs:
      ".activity.minor":
        map: "activities"
        subView: "MinorActivityHeadlessView"
        idAttr: "data-activity-id"
  )
  Pump.MajorStreamView = Pump.TemplateView.extend(
    templateName: "major-stream"
    modelName: "major"
    parts: ["major-activity", "responses", "reply", "activity-object-list", "activity-object-collection"]
    subs:
      ".activity.major":
        map: "activities"
        subView: "MajorActivityView"
        idAttr: "data-activity-id"
  )
  Pump.MinorStreamView = Pump.TemplateView.extend(
    templateName: "minor-stream"
    modelName: "minor"
    parts: ["minor-activity"]
    subs:
      ".activity.minor":
        map: "activities"
        subView: "MinorActivityView"
        idAttr: "data-activity-id"
  )
  Pump.InboxContent = Pump.ContentView.extend(
    templateName: "inbox"
    parts: ["major-stream", "minor-stream", "major-activity", "minor-activity", "responses", "reply", "activity-object-list", "activity-object-collection"]
    addMajorActivity: (act) ->
      view = this
      view.majorStreamView.showAdded act

    addMinorActivity: (act) ->
      view = this
      aview = undefined
      view.minorStreamView.showAdded act

    subs:
      "#major-stream":
        attr: "majorStreamView"
        subView: "MajorStreamView"
        subOptions:
          collection: "major"

      "#minor-stream":
        attr: "minorStreamView"
        subView: "MinorStreamView"
        subOptions:
          collection: "minor"
  )
  Pump.MajorActivityView = Pump.TemplateView.extend(
    templateName: "major-activity"
    parts: ["activity-object-list", "responses", "reply"]
    modelName: "activity"
    events:
      "click .favorite": "favoriteObject"
      "click .unfavorite": "unfavoriteObject"
      "click .share": "shareObject"
      "click .unshare": "unshareObject"
      "click .comment": "openComment"

    favoriteObject: ->
      view = this
      act = new Pump.Activity(
        verb: "favorite"
        object: view.model.object.toJSON()
      )
      stream = Pump.currentUser.minorStream
      stream.create act,
        success: (act) ->
          view.$(".favorite").removeClass("favorite").addClass("unfavorite").html "Unlike <i class=\"icon-thumbs-down\"></i>"
          Pump.addMinorActivity act


    unfavoriteObject: ->
      view = this
      act = new Pump.Activity(
        verb: "unfavorite"
        object: view.model.object.toJSON()
      )
      stream = Pump.currentUser.minorStream
      stream.create act,
        success: (act) ->
          view.$(".unfavorite").removeClass("unfavorite").addClass("favorite").html "Like <i class=\"icon-thumbs-up\"></i>"
          Pump.addMinorActivity act


    shareObject: ->
      view = this
      act = new Pump.Activity(
        verb: "share"
        object: view.model.object.toJSON()
      )
      stream = Pump.currentUser.majorStream
      stream.create act,
        success: (act) ->
          view.$(".share").removeClass("share").addClass("unshare").html "Unshare <i class=\"icon-remove\"></i>"
          Pump.addMajorActivity act


    unshareObject: ->
      view = this
      act = new Pump.Activity(
        verb: "unshare"
        object: view.model.object.toJSON()
      )
      stream = Pump.currentUser.minorStream
      stream.create act,
        success: (act) ->
          view.$(".unshare").removeClass("unshare").addClass("share").html "Share <i class=\"icon-share-alt\"></i>"
          Pump.addMinorActivity act


    openComment: ->
      view = this
      form = undefined
      if view.$("form.post-comment").length > 0
        view.$("form.post-comment textarea").focus()
      else
        form = new Pump.CommentForm(original: view.model.object)
        form.on "ready", ->
          view.$(".replies").append form.$el

        form.render()
  )
  
  # For the user page
  Pump.MajorActivityHeadlessView = Pump.MajorActivityView.extend(template: "major-activity-headless")
  Pump.CommentForm = Pump.TemplateView.extend(
    templateName: "comment-form"
    tagName: "div"
    className: "row comment-form"
    events:
      "submit .post-comment": "saveComment"

    saveComment: ->
      view = this
      text = view.$("textarea[name=\"content\"]").val()
      orig = view.options.original
      act = new Pump.Activity(
        verb: "post"
        object:
          objectType: "comment"
          content: text
      )
      stream = Pump.currentUser.minorStream
      act.object.inReplyTo = orig
      view.startSpin()
      stream.create act,
        success: (act) ->
          object = act.object
          repl = undefined
          
          # These get stripped for "posts"; re-add it
          object.set "author", act.actor
          repl = new Pump.ReplyView(model: object)
          repl.on "ready", ->
            view.stopSpin()
            view.$el.replaceWith repl.$el

          repl.render()
          Pump.addMinorActivity act

      false
  )
  Pump.MajorObjectView = Pump.TemplateView.extend(
    templateName: "major-object"
    parts: ["responses", "reply"]
  )
  Pump.ReplyView = Pump.TemplateView.extend(
    templateName: "reply"
    modelName: "reply"
  )
  Pump.MinorActivityView = Pump.TemplateView.extend(
    templateName: "minor-activity"
    modelName: "activity"
  )
  Pump.MinorActivityHeadlessView = Pump.MinorActivityView.extend(templateName: "minor-activity-headless")
  Pump.PersonView = Pump.TemplateView.extend(
    events:
      "click .follow": "followProfile"
      "click .stop-following": "stopFollowingProfile"

    followProfile: ->
      view = this
      act =
        verb: "follow"
        object: view.model.toJSON()

      stream = Pump.currentUser.stream
      stream.create act,
        success: (act) ->
          view.$(".follow").removeClass("follow").removeClass("btn-primary").addClass("stop-following").html "Stop following"


    stopFollowingProfile: ->
      view = this
      act =
        verb: "stop-following"
        object: view.model.toJSON()

      stream = Pump.currentUser.stream
      stream.create act,
        success: (act) ->
          view.$(".stop-following").removeClass("stop-following").addClass("btn-primary").addClass("follow").html "Follow"

  )
  Pump.MajorPersonView = Pump.PersonView.extend(
    templateName: "major-person"
    modelName: "person"
  )
  Pump.ProfileBlock = Pump.PersonView.extend(
    templateName: "profile-block"
    modelName: "profile"
  )
  Pump.FavoritesContent = Pump.ContentView.extend(
    templateName: "favorites"
    parts: ["profile-block", "user-content-favorites", "object-stream", "major-object", "responses", "reply", "profile-responses", "activity-object-list", "activity-object-collection"]
    subs:
      "#profile-block":
        attr: "profileBlock"
        subView: "ProfileBlock"
        subOptions:
          model: "profile"

      "#user-content-favorites":
        attr: "userContent"
        subView: "FavoritesUserContent"
        subOptions:
          collection: "objects"
          data: ["profile"]
  )
  Pump.FavoritesUserContent = Pump.TemplateView.extend(
    templateName: "user-content-favorites"
    modelName: "objects"
    parts: ["object-stream", "major-object", "responses", "reply", "profile-responses", "activity-object-collection"]
    subs:
      ".object.major":
        map: "objects"
        subView: "MajorObjectView"
        idAttr: "data-object-id"
  )
  Pump.FollowersContent = Pump.ContentView.extend(
    templateName: "followers"
    parts: ["profile-block", "user-content-followers", "people-stream", "major-person", "profile-responses"]
    subs:
      "#profile-block":
        attr: "profileBlock"
        subView: "ProfileBlock"
        subOptions:
          model: "profile"

      "#user-content-followers":
        attr: "userContent"
        subView: "FollowersUserContent"
        subOptions:
          collection: "people"
          data: ["profile"]
  )
  Pump.FollowersUserContent = Pump.TemplateView.extend(
    templateName: "user-content-followers"
    modelName: "people"
    parts: ["people-stream", "major-person", "profile-responses"]
    subs:
      ".person.major":
        map: "people"
        subView: "MajorPersonView"
        idAttr: "data-person-id"
  )
  Pump.FollowingContent = Pump.ContentView.extend(
    templateName: "following"
    parts: ["profile-block", "user-content-following", "people-stream", "major-person", "profile-responses"]
    subs:
      "#profile-block":
        attr: "profileBlock"
        subView: "ProfileBlock"
        subOptions:
          model: "profile"

      "#user-content-following":
        attr: "userContent"
        subView: "FollowingUserContent"
        subOptions:
          collection: "people"
          data: ["profile"]
  )
  Pump.FollowingUserContent = Pump.TemplateView.extend(
    templateName: "user-content-following"
    modelName: "people"
    parts: ["people-stream", "major-person", "profile-responses"]
    subs:
      ".person.major":
        map: "people"
        subView: "MajorPersonView"
        idAttr: "data-person-id"
  )
  Pump.ListsContent = Pump.ContentView.extend(
    templateName: "lists"
    parts: ["profile-block", "user-content-lists", "list-menu", "list-menu-item", "profile-responses"]
    subs:
      "#profile-block":
        attr: "profileBlock"
        subView: "ProfileBlock"
        subOptions:
          model: "profile"

      "#user-content-lists":
        attr: "userContent"
        subView: "ListsUserContent"
        subOptions:
          data: ["profile", "lists"]
  )
  Pump.ListsUserContent = Pump.TemplateView.extend(
    templateName: "user-content-lists"
    parts: ["list-menu", "list-menu-item", "list-content-lists"]
    subs:
      "#list-menu-inner":
        attr: "listMenu"
        subView: "ListMenu"
        subOptions:
          collection: "lists"
          data: ["profile"]
  )
  Pump.ListMenu = Pump.TemplateView.extend(
    templateName: "list-menu"
    modelName: "profile"
    parts: ["list-menu-item"]
    el: ".list-menu-block"
    events:
      "click .new-list": "newList"

    newList: ->
      Pump.showModal Pump.NewListModal,
        data:
          user: Pump.currentUser


    subs:
      ".list":
        map: "lists"
        subView: "ListMenuItem"
        idAttr: "data-list-id"
  )
  Pump.ListMenuItem = Pump.TemplateView.extend(
    templateName: "list-menu-item"
    modelName: "listItem"
    tagName: "ul"
    className: "list-menu-wrapper"
  )
  Pump.ListsListContent = Pump.TemplateView.extend(templateName: "list-content-lists")
  Pump.ListContent = Pump.ContentView.extend(
    templateName: "list"
    parts: ["profile-block", "profile-responses", "user-content-list", "list-content-list", "people-stream", "major-person", "list-menu", "list-menu-item"]
    subs:
      "#profile-block":
        attr: "profileBlock"
        subView: "ProfileBlock"
        subOptions:
          model: "profile"

      "#user-content-list":
        attr: "userContent"
        subView: "ListUserContent"
        subOptions:
          data: ["profile", "lists", "list"]
  )
  Pump.ListUserContent = Pump.TemplateView.extend(
    templateName: "user-content-list"
    parts: ["people-stream", "list-content-list", "major-person", "list-menu-item", "list-menu"]
    subs:
      "#list-menu-inner":
        attr: "listMenu"
        subView: "ListMenu"
        subOptions:
          collection: "lists"
          data: ["profile"]

      "#list-content-list":
        attr: "listContent"
        subView: "ListListContent"
        subOptions:
          model: "list"
          data: ["profile"]
  )
  Pump.ListListContent = Pump.TemplateView.extend(
    templateName: "list-content-list"
    modelName: "list"
    parts: ["people-stream", "major-person"]
    setupSubs: ->
      view = this
      model = view.model
      if model and model.members
        model.members.each (person) ->
          $el = view.$("div[data-person-id='" + person.id + "']")
          aview = undefined
          if $el.length > 0
            aview = new Pump.MajorPersonView(
              el: $el
              model: person
            )

  )
  Pump.SettingsContent = Pump.ContentView.extend(
    templateName: "settings"
    modelName: "profile"
    events:
      "submit #settings": "saveSettings"

    fileCount: 0
    ready: ->
      view = this
      view.setupSubs()
      if view.$("#avatar-fineupload").length > 0
        view.$("#avatar-fineupload").fineUploader(
          request:
            endpoint: "/main/upload"

          text:
            uploadButton: "<i class=\"icon-upload icon-white\"></i> Avatar file"

          template: "<div class=\"qq-uploader\">" + "<pre class=\"qq-upload-drop-area\"><span>{dragZoneText}</span></pre>" + "<div class=\"qq-drop-processing\"></div>" + "<div class=\"qq-upload-button btn btn-success\">{uploadButtonText}</div>" + "<ul class=\"qq-upload-list\"></ul>" + "</div>"
          classes:
            success: "alert alert-success"
            fail: "alert alert-error"

          autoUpload: false
          multiple: false
          validation:
            allowedExtensions: ["jpeg", "jpg", "png", "gif", "svg", "svgz"]
            acceptFiles: "image/*"
        ).on("submit", (id, fileName) ->
          view.fileCount++
          true
        ).on("cancel", (id, fileName) ->
          view.fileCount--
          true
        ).on("complete", (event, id, fileName, responseJSON) ->
          stream = Pump.currentUser.majorStream
          act = new Pump.Activity(
            verb: "post"
            cc: [
              id: "http://activityschema.org/collection/public"
              objectType: "collection"
            ]
            object: responseJSON.obj
          )
          stream.create act,
            success: (act) ->
              view.saveProfile act.object.get("fullImage")

            error: ->
              view.showError "Couldn't create"
              view.stopSpin()

        ).on "error", (event, id, fileName, reason) ->
          view.showError reason
          view.stopSpin()


    saveProfile: (img) ->
      view = this
      profile = Pump.currentUser.profile
      props =
        displayName: view.$("#realname").val()
        location:
          objectType: "place"
          displayName: view.$("#location").val()

        summary: view.$("#bio").val()

      props.image = img  if img
      profile.save props,
        success: (resp, status, xhr) ->
          view.showSuccess "Saved settings."
          view.stopSpin()

        error: (model, error, options) ->
          view.showError error.message
          view.stopSpin()


    saveSettings: ->
      view = this
      user = Pump.currentUser
      profile = user.profile
      haveNewAvatar = (view.fileCount > 0)
      view.startSpin()
      
      # XXX: Validation?
      if haveNewAvatar
        
        # This will save the profile afterwards
        view.$("#avatar-fineupload").fineUploader "uploadStoredFiles"
      else
        
        # No new image
        view.saveProfile null
      false
  )
  Pump.AccountContent = Pump.ContentView.extend(
    templateName: "account"
    modelName: "user"
    events:
      "submit #account": "saveAccount"

    saveAccount: ->
      view = this
      user = Pump.currentUser
      password = view.$("#password").val()
      repeat = view.$("#repeat").val()
      if password isnt repeat
        view.showError "Passwords don't match."
      else if password.length < 8
        view.showError "Password must be 8 chars or more."
      else if /^[a-z]+$/.test(password.toLowerCase()) or /^[0-9]+$/.test(password)
        view.showError "Passwords have to have at least one letter and one number."
      else
        view.startSpin()
        user.save "password", password,
          success: (resp, status, xhr) ->
            view.showSuccess "Saved."
            view.stopSpin()

          error: (model, error, options) ->
            view.showError error.message
            view.stopSpin()

      false
  )
  Pump.ObjectContent = Pump.ContentView.extend(
    templateName: "object"
    modelName: "object"
    parts: ["responses", "reply", "activity-object-collection"]
  )
  Pump.PostNoteModal = Pump.TemplateView.extend(
    tagName: "div"
    className: "modal-holder"
    templateName: "post-note"
    ready: ->
      view = this
      view.$("#note-content").wysihtml5 customTemplates: Pump.wysihtml5Tmpl
      view.$("#note-to").select2()
      view.$("#note-cc").select2()

    events:
      "click #send-note": "postNote"

    postNote: (ev) ->
      view = this
      text = view.$("#post-note #note-content").val()
      to = view.$("#post-note #note-to").val()
      cc = view.$("#post-note #note-cc").val()
      act = new Pump.Activity(
        verb: "post"
        object:
          objectType: "note"
          content: text
      )
      stream = Pump.currentUser.majorStream
      strToObj = (str) ->
        colon = str.indexOf(":")
        type = str.substr(0, colon)
        id = str.substr(colon + 1)
        new Pump.ActivityObject(
          id: id
          objectType: type
        )

      act.to = new Pump.ActivityObjectBag(_.map(to, strToObj))  if to and to.length > 0
      act.cc = new Pump.ActivityObjectBag(_.map(cc, strToObj))  if cc and cc.length > 0
      view.startSpin()
      stream.create act,
        success: (act) ->
          view.$el.modal "hide"
          view.stopSpin()
          Pump.resetWysihtml5 view.$("#note-content")
          
          # Reload the current page
          Pump.addMajorActivity act
          view.remove()

  )
  Pump.PostPictureModal = Pump.TemplateView.extend(
    tagName: "div"
    className: "modal-holder"
    templateName: "post-picture"
    events:
      "click #send-picture": "postPicture"

    ready: ->
      view = this
      view.$("#picture-to").select2()
      view.$("#picture-cc").select2()
      view.$("#picture-description").wysihtml5 customTemplates: Pump.wysihtml5Tmpl
      if view.$("#picture-fineupload").length > 0
        
        # Reload the current content
        view.$("#picture-fineupload").fineUploader(
          request:
            endpoint: "/main/upload"

          text:
            uploadButton: "<i class=\"icon-upload icon-white\"></i> Picture file"

          template: "<div class=\"qq-uploader\">" + "<pre class=\"qq-upload-drop-area\"><span>{dragZoneText}</span></pre>" + "<div class=\"qq-drop-processing\"></div>" + "<div class=\"qq-upload-button btn btn-success\">{uploadButtonText}</div>" + "<ul class=\"qq-upload-list\"></ul>" + "</div>"
          classes:
            success: "alert alert-success"
            fail: "alert alert-error"

          autoUpload: false
          multiple: false
          validation:
            allowedExtensions: ["jpeg", "jpg", "png", "gif", "svg", "svgz"]
            acceptFiles: "image/*"
        ).on("complete", (event, id, fileName, responseJSON) ->
          stream = Pump.currentUser.majorStream
          to = view.$("#post-picture #picture-to").val()
          cc = view.$("#post-picture #picture-cc").val()
          strToObj = (str) ->
            colon = str.indexOf(":")
            type = str.substr(0, colon)
            id = str.substr(colon + 1)
            Pump.ActivityObject.unique
              id: id
              objectType: type


          act = new Pump.Activity(
            verb: "post"
            object: responseJSON.obj
          )
          act.to = new Pump.ActivityObjectBag(_.map(to, strToObj))  if to and to.length > 0
          act.cc = new Pump.ActivityObjectBag(_.map(cc, strToObj))  if cc and cc.length > 0
          stream.create act,
            success: (act) ->
              view.$el.modal "hide"
              view.stopSpin()
              view.$("#picture-fineupload").fineUploader "reset"
              Pump.resetWysihtml5 view.$("#picture-description")
              view.$("#picture-title").val ""
              Pump.addMajorActivity act
              view.remove()

        ).on "error", (event, id, fileName, reason) ->
          view.showError reason


    postPicture: (ev) ->
      view = this
      description = view.$("#post-picture #picture-description").val()
      title = view.$("#post-picture #picture-title").val()
      params = {}
      params.title = title  if title
      
      # XXX: HTML
      params.description = description  if description
      view.$("#picture-fineupload").fineUploader "setParams", params
      view.startSpin()
      view.$("#picture-fineupload").fineUploader "uploadStoredFiles"
  )
  Pump.NewListModal = Pump.TemplateView.extend(
    tagName: "div"
    className: "modal-holder"
    templateName: "new-list"
    ready: ->
      view = this
      view.$("#list-description").wysihtml5 customTemplates: Pump.wysihtml5Tmpl

    events:
      "click #save-new-list": "saveNewList"

    saveNewList: ->
      view = this
      description = view.$("#new-list #list-description").val()
      name = view.$("#new-list #list-name").val()
      act = undefined
      stream = Pump.currentUser.minorStream
      unless name
        view.showError "Your list must have a name."
      else
        
        # XXX: any other validation? Check uniqueness here?
        
        # XXX: to/cc ?
        act = new Pump.Activity(
          verb: "create"
          object: new Pump.ActivityObject(
            objectType: "collection"
            objectTypes: ["person"]
            displayName: name
            content: description
          )
        )
        view.startSpin()
        stream.create act,
          success: (act) ->
            aview = undefined
            view.$el.modal "hide"
            view.stopSpin()
            Pump.resetWysihtml5 view.$("#list-description")
            view.$("#list-name").val ""
            view.remove()
            
            # it's minor
            Pump.addMinorActivity act
            if $("#list-menu-inner").length > 0
              aview = new Pump.ListMenuItem(model: act.object)
              aview.on "ready", ->
                el = aview.$("li")
                el.hide()
                $("#list-menu-inner").prepend el
                el.slideDown "fast"
                
                # Go to the new list page
                Pump.router.navigate act.object.get("url"), true

              aview.render()

      false
  )
  Pump.BodyView = Backbone.View.extend(
    initialize: (options) ->
      _.bindAll this, "navigateToHref"

    el: "body"
    events:
      "click a": "navigateToHref"

    navigateToHref: (ev) ->
      el = (ev.srcElement or ev.currentTarget)
      pathname = el.pathname # XXX: HTML5
      here = window.location
      if not el.host or el.host is here.host
        try
          Pump.router.navigate pathname, true
        catch e
          Pump.error e
        
        # Always return false
        false
      else
        true

    setTitle: (title) ->
      @$("title").html title + " - " + Pump.config.site

    setContent: (options, callback) ->
      View = options.contentView
      title = options.title
      body = this
      oldContent = body.content
      userContentOptions = undefined
      listContentOptions = undefined
      newView = undefined
      parent = undefined
      profile = undefined
      if options.model
        profile = options.model
      else profile = options.data.profile  if options.data
      Pump.unfollowStreams()
      
      # XXX: double-check this
      body.content = new View(options)
      
      # We try and only update the parts that have changed
      if oldContent and options.userContentView and oldContent.profileBlock and oldContent.profileBlock.model.get("id") is profile.get("id")
        body.content.profileBlock = oldContent.profileBlock
        if options.userContentCollection
          userContentOptions = _.extend(
            collection: options.userContentCollection
          , options)
        else
          userContentOptions = options
        body.content.userContent = new options.userContentView(userContentOptions)
        if options.listContentView and oldContent.userContent.listMenu
          body.content.userContent.listMenu = oldContent.userContent.listMenu
          if options.listContentModel
            listContentOptions = _.extend(
              model: options.listContentModel
            , options)
          else
            listContentOptions = options
          body.content.userContent.listContent = new options.listContentView(listContentOptions)
          parent = "#list-content"
          newView = body.content.userContent.listContent
        else
          parent = "#user-content"
          newView = body.content.userContent
      else
        parent = "#content"
        newView = body.content
      newView.once "ready", ->
        body.setTitle title
        body.$(parent).children().replaceWith newView.$el
        Pump.followStreams()
        callback()  if callback

      newView.render()
  )
  Pump.showModal = (Cls, options) ->
    modalView = undefined
    
    # If we've got it attached already, just show it
    modalView = new Cls(options)
    
    # When it's ready, show immediately
    modalView.on "ready", ->
      $("body").append modalView.el
      modalView.$el.modal "show"

    
    # render it (will fire "ready")
    modalView.render()

  Pump.resetWysihtml5 = (el) ->
    fancy = el.data("wysihtml5")
    fancy.editor.clear()  if fancy and fancy.editor and fancy.editor.clear
    $(".wysihtml5-command-active", fancy.toolbar).removeClass "wysihtml5-command-active"
    el

  Pump.addMajorActivity = (act) ->
    Pump.body.content.addMajorActivity act  if Pump.body.content

  Pump.addMinorActivity = (act) ->
    Pump.body.content.addMinorActivity act  if Pump.body.content
) window._, window.$, window.Backbone, window.Pump
