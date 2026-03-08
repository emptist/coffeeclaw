# OpenClaw CoffeeScript Chat App
# Run with: coffee chat.coffee
# Note: Sessions are auto-cleared on start

{ execSync } = require 'child_process'
fs = require 'fs'
path = require 'path'
http = require 'http'

CONFIG =
  host: '127.0.0.1'
  port: 18789
  token: 'ca965d471f82d8d7abf301dae7ec28ec76e470093b4309f3'
  model: 'glm/GLM-4-Flash'

# Clear old sessions on start
sessionsDir = path.join process.env.HOME, '.openclaw/agents/main/sessions'
sessionsFile = path.join process.env.HOME, '.openclaw/agents/main/sessions.json'

try
  if fs.existsSync(sessionsFile)
    fs.unlinkSync(sessionsFile)
  if fs.existsSync(sessionsDir)
    fs.readdirSync(sessionsDir).forEach (file) ->
      fs.unlinkSync(path.join(sessionsDir, file))
  console.log '🗑️  Cleared old sessions'
catch e
  console.log 'Note: Could not clear sessions'

sendMessage = (message, callback) ->
  postData = JSON.stringify
    model: CONFIG.model
    messages: [{ role: 'user', content: message }]
    stream: false

  options =
    hostname: CONFIG.host
    port: CONFIG.port
    path: '/v1/chat/completions'
    method: 'POST'
    headers:
      'Content-Type': 'application/json'
      'Authorization': "Bearer #{CONFIG.token}"
      'Content-Length': Buffer.byteLength(postData)

  req = http.request options, (res) ->
    data = ''
    res.on 'data', (chunk) -> data += chunk
    res.on 'end', -> callback null, data

  req.on 'error', (err) -> callback err
  req.write postData
  req.end()

# Interactive chat
readline = require 'readline'
rl = readline.createInterface 
  input: process.stdin
  output: process.stdout

console.log '\n🤖 OpenClaw Chat (type "exit" to quit)\n'

ask = ->
  rl.question 'You: ', (line) ->
    return process.exit() if line.trim() is 'exit'
    return ask() if line.trim() is ''
    
    sendMessage line.trim(), (err, response) ->
      if err
        console.log "Error: #{err.message}\n"
      else
        try
          data = JSON.parse response
          if data.choices and data.choices[0]
            content = data.choices[0].message.content
            # Handle markdown response
            if content.startsWith('#') or content.includes('\n')
              console.log "Bot:\n#{content}\n"
            else
              console.log "Bot: #{content}\n"
          else if data.error
            console.log "Error: #{data.error.message}\n"
          else
            console.log "Bot: #{JSON.stringify data, null, 2}\n"
        catch e
          console.log "Bot: #{response}\n"
      ask()

ask()
