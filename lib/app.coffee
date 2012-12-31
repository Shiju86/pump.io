# app.js
#
# main function for activity pump application
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
auth = require("connect-auth")
Step = require("step")
databank = require("databank")
express = require("express")
_ = require("underscore")
fs = require("fs")
path = require("path")
Logger = require("bunyan")
uuid = require("node-uuid")
email = require("emailjs")
api = require("../routes/api")
web = require("../routes/web")
webfinger = require("../routes/webfinger")
clientreg = require("../routes/clientreg")
dialback = require("../routes/dialback")
oauth = require("../routes/oauth")
uploads = require("../routes/uploads")
schema = require("./schema").schema
HTTPError = require("./httperror").HTTPError
Provider = require("./provider").Provider
URLMaker = require("./urlmaker").URLMaker
rawBody = require("./rawbody").rawBody
pumpsocket = require("./pumpsocket")
Databank = databank.Databank
DatabankObject = databank.DatabankObject
DatabankStore = require("connect-databank")(express)
makeApp = (config, callback) ->
  params = undefined
  defaults =
    port: 31337
    hostname: "127.0.0.1"
    site: "pump.io"
    sockjs: true
    debugClient: false

  port = undefined
  hostname = undefined
  address = undefined
  log = undefined
  db = undefined
  logParams =
    name: "pump.io"
    serializers:
      req: Logger.stdSerializers.req
      res: Logger.stdSerializers.res
      user: (user) ->
        if user
          nickname: user.nickname
        else
          nickname: "<none>"

      client: (client) ->
        if client
          key: client.consumer_key
          title: client.title or "<none>"
        else
          key: "<none>"
          title: "<none>"

  
  # Fill in defaults if they're not there
  config = _.defaults(config, defaults)
  port = config.port
  hostname = config.hostname
  address = config.address or config.hostname
  if config.logfile
    logParams.streams = [path: config.logfile]
  else if config.nologger
    logParams.streams = [path: "/dev/null"]
  else
    logParams.streams = [stream: process.stderr]
  log = new Logger(logParams)
  log.info "Initializing pump.io"
  
  # Initiate the DB
  if _(config).has("params")
    params = config.params
  else
    params = {}
  if _(params).has("schema")
    _.extend params.schema, schema
  else
    params.schema = schema
  db = Databank.get(config.driver, params)
  
  # Connect...
  log.info "Connecting to databank with driver '" + config.driver + "'"
  db.connect {}, (err) ->
    useHTTPS = _(config).has("key")
    useBounce = _(config).has("bounce") and config.bounce
    app = undefined
    io = undefined
    bounce = undefined
    maillog = undefined
    smtp = undefined
    from = undefined
    requestLogger = (log) ->
      (req, res, next) ->
        weblog = log.child(
          req_id: uuid.v4()
          component: "web"
        )
        end = res.end
        req.log = weblog
        res.end = (chunk, encoding) ->
          rec = undefined
          res.end = end
          res.end chunk, encoding
          rec =
            req: req
            res: res

          rec.user = req.remoteUser  if _(req).has("remoteUser")
          rec.client = req.client  if _(req).has("client")
          weblog.info rec

        next()

    if err
      log.error err
      callback err, null
      return
    if useHTTPS
      log.info "Setting up HTTPS server."
      app = express.createServer(
        key: fs.readFileSync(config.key)
        cert: fs.readFileSync(config.cert)
      )
      if useBounce
        log.info "Setting up micro-HTTP server to bounce to HTTPS."
        bounce = express.createServer((req, res, next) ->
          host = req.header("Host")
          res.redirect "https://" + host + req.url, 301
        )
    else
      log.info "Setting up HTTP server."
      app = express.createServer()
    app.config = config
    if config.smtpserver
      maillog = log.child(component: "mail")
      maillog.info "Connecting to SMTP server " + config.smtpserver
      smtp = email.server.connect(
        user: config.smtpuser or null
        password: config.smtppass or null
        host: config.smtpserver
        port: config.smtpport or null
        ssl: config.smtpusessl or false
      )
      from = config.smtpfrom or "no-reply@" + hostname
      app.sendEmail = (props, callback) ->
        message = _.extend(
          from: from
        , props)
        smtp.send message, (err, message) ->
          if err
            maillog.error
              msg: "Sending email"
              to: message.to or null
              subject: message.subject or null

            callback err, null
          else
            maillog.info
              msg: "Message sent"
              to: message.to or null
              subject: message.subject or null

            callback null, message

    cleanup = config.cleanup or 600000
    dbstore = new DatabankStore(db, log, cleanup)
    if not _(config).has("noweb") or not config.noweb
      app.session = express.session(
        secret: (if (_(config).has("sessionSecret")) then config.sessionSecret else "insecure")
        store: dbstore
      )
    
    # Configuration
    app.configure ->
      
      # Templates are in public
      app.set "views", __dirname + "/../public/template"
      app.set "view engine", "utml"
      app.use requestLogger(log)
      app.use rawBody
      app.use express.bodyParser()
      app.use express.cookieParser()
      app.use express.query()
      app.use express.methodOverride()
      app.use express.favicon()
      app.provider = new Provider(log)
      app.use (req, res, next) ->
        res.local "config", config
        res.local "data", {}
        res.local "page", {}
        res.local "template", {}
        
        # Initialize null
        res.local "remoteUser", null
        res.local "user", null
        res.local "client", null
        res.local "nologin", false
        next()

      app.use auth([auth.Oauth(
        name: "client"
        realm: "OAuth"
        oauth_provider: app.provider
        oauth_protocol: (if (useHTTPS) then "https" else "http")
        authenticate_provider: null
        authorize_provider: null
        authorization_finished_provider: null
      ), auth.Oauth(
        name: "user"
        realm: "OAuth"
        oauth_provider: app.provider
        oauth_protocol: (if (useHTTPS) then "https" else "http")
        authenticate_provider: oauth.authenticate
        authorize_provider: oauth.authorize
        authorization_finished_provider: oauth.authorizationFinished
      )])
      app.use express["static"](__dirname + "/../public")
      app.use app.router

    app.error (err, req, res, next) ->
      log.error err
      if err instanceof HTTPError
        if req.xhr or req.originalUrl.substr(0, 5) is "/api/"
          res.json
            error: err.message
          , err.code
        else if req.accepts("html")
          res.render "error",
            page:
              title: "Error"

            data:
              error: err

        else
          res.writeHead err.code,
            "Content-Type": "text/plain"

          res.end err.message
      else
        next err

    
    # Routes
    api.addRoutes app
    webfinger.addRoutes app
    dialback.addRoutes app
    clientreg.addRoutes app
    if _.has(config, "uploaddir")
      
      # Simple boolean flag
      config.canUpload = true
      uploads.addRoutes app
    
    # Use "noweb" to disable Web site (API engine only)
    if not _(config).has("noweb") or not config.noweb
      web.addRoutes app
    else
      
      # A route to show the API doc at root
      app.get "/", (req, res, next) ->
        Showdown = require("showdown")
        converter = new Showdown.converter()
        Step (->
          fs.readFile path.join(__dirname, "..", "API.md"), this
        ), (err, data) ->
          html = undefined
          markdown = undefined
          if err
            next err
          else
            markdown = data.toString()
            html = converter.makeHtml(markdown)
            res.render "doc",
              page:
                title: "API"

              data:
                html: html



    DatabankObject.bank = db
    URLMaker.hostname = hostname
    URLMaker.port = port
    if _(config).has("serverUser")
      app.on "listening", ->
        process.setuid config.serverUser

    pumpsocket.connect app, log  if config.sockjs
    app.run = (callback) ->
      self = this
      removeListeners = ->
        self.removeListener "listening", listenSuccessHandler
        self.removeListener "err", listenErrorHandler

      listenErrorHandler = (err) ->
        removeListeners()
        log.error err
        callback err

      listenSuccessHandler = ->
        removeBounceListeners = ->
          bounce.removeListener "listening", bounceSuccess
          bounce.removeListener "err", bounceError

        bounceError = (err) ->
          removeBounceListeners()
          log.error err
          callback err

        bounceSuccess = ->
          log.info "Finished setting up bounce server."
          removeBounceListeners()
          callback null

        log.info "Finished setting up main server."
        removeListeners()
        if useBounce
          bounce.on "error", bounceError
          bounce.on "listening", bounceSuccess
          bounce.listen 80, hostname
        else
          callback null

      @on "error", listenErrorHandler
      @on "listening", listenSuccessHandler
      log.info "Listening on " + port + " for host " + address
      @listen port, address

    callback null, app


exports.makeApp = makeApp
