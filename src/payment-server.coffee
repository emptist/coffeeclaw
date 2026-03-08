# CoffeeClaw Payment Server
# Handles subscriptions, quotas, and payments via Stripe

express = require 'express'
cors = require 'cors'
crypto = require 'crypto'
fs = require 'fs'
path = require 'path'

app = express()
app.use express.json()
app.use cors()

PORT = process.env.PORT or 18790
STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY
BASE_PRICE_ID = process.env.STRIPE_PRICE_ID or 'price_yearly_12usd'
CNY_PRICE_ID = process.env.CNY_PRICE_ID or 'price_yearly_36cny'

FREE_CREDIT_USD = 2
FREE_CREDIT_CNY = 6

dataDir = path.join process.env.HOME, '.openclaw', 'subscription'
fs.mkdirSync dataDir, { recursive: true }

usersFile = path.join dataDir, 'users.json'
transactionsFile = path.join dataDir, 'transactions.json'

loadUsers = ->
  try
    if fs.existsSync usersFile
      JSON.parse fs.readFileSync usersFile, 'utf8'
    else
      {}
  catch
    {}

saveUsers = (users) ->
  fs.writeFileSync usersFile, JSON.stringify(users, null, 2)

loadTransactions = ->
  try
    if fs.existsSync transactionsFile
      JSON.parse fs.readFileSync transactionsFile, 'utf8'
    else
      []
  catch
    []

saveTransaction = (tx) ->
  txs = loadTransactions()
  txs.push { ...tx, createdAt: new Date().toISOString() }
  fs.writeFileSync transactionsFile, JSON.stringify(txs, null, 2)

generateDeviceId = (machineId) ->
  crypto.createHash('sha256').update(machineId).digest('hex').substring(0, 32)

isChinaRegion = (region) ->
  region?.toLowerCase() in ['cn', 'china', 'zh']

getFreeCredit = (region) ->
  if isChinaRegion(region) then FREE_CREDIT_CNY else FREE_CREDIT_USD

app.post '/api/quota/init', (req, res) ->
  { deviceId, region } = req.body
  
  unless deviceId
    return res.status(400).json { error: 'deviceId required' }
  
  deviceId = generateDeviceId(deviceId)
  users = loadUsers()
  
  if users[deviceId]
    user = users[deviceId]
    user.region = region if region
    users[deviceId] = user
    saveUsers(users)
    
    res.json
      deviceId: deviceId
      credit: user.credit
      paid: user.paid
      subscriptionStatus: user.subscriptionStatus
      expiresAt: user.expiresAt
      createdAt: user.createdAt
  else
    freeCredit = getFreeCredit(region)
    newUser =
      credit: freeCredit
      paid: false
      subscriptionStatus: 'free'
      region: region or 'global'
      createdAt: new Date().toISOString()
      usage: []
    
    users[deviceId] = newUser
    saveUsers(users)
    
    res.json
      deviceId: deviceId
      credit: freeCredit
      paid: false
      subscriptionStatus: 'free'
      expiresAt: null
      createdAt: newUser.createdAt

app.get '/api/quota/:deviceId', (req, res) ->
  deviceId = generateDeviceId(req.params.deviceId)
  users = loadUsers()
  user = users[deviceId]
  
  unless user
    return res.status(404).json { error: 'User not found' }
  
  resJson =
    deviceId: deviceId
    credit: user.credit
    paid: user.paid
    subscriptionStatus: user.subscriptionStatus
    expiresAt: user.expiresAt
  
  if user.paid
    resJson.lifetime = true
  
  res.json resJson

app.post '/api/quota/use', (req, res) ->
  { deviceId, amount } = req.body
  amount = amount or 1
  
  deviceId = generateDeviceId(deviceId)
  users = loadUsers()
  user = users[deviceId]
  
  unless user
    return res.status(404).json { error: 'User not found' }
  
  if user.paid
    res.json
      credit: -1
      remaining: -1
      unlimited: true
    return
  
  if user.credit <= 0
    return res.status(403).json {
      error: 'quota_exceeded'
      message: 'Credit exhausted'
      credit: 0
    }
  
  user.credit = Math.max(0, user.credit - amount)
  user.usage ?= []
  user.usage.push
    timestamp: new Date().toISOString()
    amount: amount
  
  user.usage = user.usage.slice(-100)
  
  users[deviceId] = user
  saveUsers(users)
  
  res.json
    credit: user.credit
    remaining: user.credit

app.post '/api/payment/create-session', (req, res) ->
  { deviceId, region, priceId } = req.body
  
  unless deviceId
    return res.status(400).json { error: 'deviceId required' }
  
  deviceId = generateDeviceId(deviceId)
  priceId = priceId or BASE_PRICE_ID
  
  unless STRIPE_SECRET_KEY
    return res.status(500).json {
      error: 'Payment not configured'
      message: 'Stripe not configured. Use free tier for now.'
      offline: true
    }
  
  stripe = require('stripe')(STRIPE_SECRET_KEY)
  
  successUrl = 'https://coffeeclaw.app/payment-success?session_id={CHECKOUT_SESSION_ID}'
  cancelUrl = 'https://coffeeclaw.app/payment-cancelled'
  
  if process.env.NODE_ENV == 'development'
    successUrl = 'http://localhost:18789/payment-success?session_id={CHECKOUT_SESSION_ID}'
    cancelUrl = 'http://localhost:18789/payment-cancelled'
  
  sessionOptions =
    payment_method_types: ['card']
    line_items: [
      price: priceId
      quantity: 1
    ]
    mode: 'subscription'
    success_url: successUrl
    cancel_url: cancelUrl
    metadata:
      deviceId: deviceId
  
  if isChinaRegion(region)
    sessionOptions.payment_method_types.push('alipay', 'wechat_pay')
  
  stripe.checkout.sessions.create sessionOptions, (err, session) ->
    if err
      console.error 'Stripe error:', err.message
      return res.status(500).json { error: 'payment_error', message: err.message }
    
    users = loadUsers()
    if users[deviceId]
      users[deviceId].pendingPayment = session.id
      saveUsers(users)
    
    res.json
      sessionId: session.id
      url: session.url
      paymentMethods: sessionOptions.payment_method_types

app.post '/api/payment/verify', (req, res) ->
  { deviceId, sessionId } = req.body
  
  unless STRIPE_SECRET_KEY
    return res.status(500).json { error: 'Payment not configured' }
  
  deviceId = generateDeviceId(deviceId)
  stripe = require('stripe')(STRIPE_SECRET_KEY)
  
  stripe.checkout.sessions.retrieve sessionId, (err, session) ->
    if err
      return res.status(500).json { error: err.message }
    
    if session.payment_status == 'paid'
      users = loadUsers()
      
      if users[deviceId]
        users[deviceId].paid = true
        users[deviceId].subscriptionStatus = 'lifetime'
        users[deviceId].stripeCustomerId = session.customer
        users[deviceId].paidAt = new Date().toISOString()
        delete users[deviceId].pendingPayment
        
        saveUsers(users)
        
        saveTransaction
          deviceId: deviceId
          amount: session.amount_total
          currency: session.currency
          status: 'paid'
          stripeSessionId: sessionId
        
        res.json
          success: true
          lifetime: true
      else
        res.status(404).json { error: 'User not found' }
    else
      res.status(400).json { error: 'Payment not completed' }

app.get '/api/payment/status/:deviceId', (req, res) ->
  deviceId = generateDeviceId(req.params.deviceId)
  users = loadUsers()
  user = users[deviceId]
  
  unless user
    return res.status(404).json { error: 'User not found' }
  
  resJson =
    paid: user.paid
    subscriptionStatus: user.subscriptionStatus
    paidAt: user.paidAt
    pendingPayment: !!user.pendingPayment
  
  if user.paid
    resJson.lifetime = true
  
  res.json resJson

console.log "CoffeeClaw Payment Server starting on port #{PORT}"
app.listen PORT, ->
  console.log "Payment API available at http://localhost:#{PORT}"
  console.log "Set STRIPE_SECRET_KEY env var to enable payments"
