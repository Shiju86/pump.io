Step = require("step")
cluster = require("cluster")
mod = require("../../lib/app")
fs = require("fs")
path = require("path")
Dispatch = require("../../lib/dispatch")
makeApp = mod.makeApp
tc = JSON.parse(fs.readFileSync(path.resolve(__dirname, "..", "config.json")))
config =
  driver: tc.driver
  params: tc.params
  sockjs: false
  nologger: true

app = null
i = undefined
parts = undefined
worker = undefined
process.env.NODE_ENV = "test"
i = 2
while i < process.argv.length
  parts = process.argv[i].split("=")
  config[parts[0]] = parts[1]
  i++
config.port = parseInt(config.port, 10)
if cluster.isMaster
  worker = cluster.fork()
  worker.on "message", (msg) ->
    switch msg.cmd
      when "error", "listening"
        process.send msg
      else

  Dispatch.start()
else
  Step (->
    makeApp config, this
  ), ((err, res) ->
    throw err  if err
    app = res
    app.run this
  ), (err) ->
    if err
      process.send
        cmd: "error"
        value: err

    else
      process.send cmd: "listening"

