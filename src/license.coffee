# License class for managing user license and billing information
# Note: deviceId was removed as it's not used - billing is not device-restricted

class License
  # Class properties
  @INITIAL_BALANCE = 1  # USD
  @MONTHLY_FEE = 1      # USD per month
  
  constructor: ->
    @createdAt = new Date().toISOString()
    @balance = License.INITIAL_BALANCE
    @currency = 'usd'
    @paid = false
    @plan = null
    @lastDeduction = null
  
  # Get current balance
  getBalance: -> @balance
  
  # Check if lifetime license
  isLifetime: -> @paid and @plan == 'lifetime'
  
  # Check if active (has balance or lifetime)
  isActive: -> @isLifetime() or @balance > 0
  
  # Set plan and mark as paid
  setPlan: (plan, amount) ->
    @plan = plan
    @paid = true
    if plan == 'lifetime'
      @balance = 0
    else if amount
      @balance = (@balance or 0) + amount
    this
  
  # Add balance
  addBalance: (amount) ->
    @balance = (@balance or 0) + amount
    @paid = true
    this
  
  # Process monthly deduction
  # Returns true if deduction was made
  processMonthlyDeduction: ->
    return false if @isLifetime()
    return false unless @balance?
    
    now = new Date()
    createdAt = new Date(@createdAt)
    
    monthsSinceCreation = (now.getFullYear() - createdAt.getFullYear()) * 12 + (now.getMonth() - createdAt.getMonth())
    
    if @lastDeduction
      lastDeduction = new Date(@lastDeduction)
      monthsSinceLastDeduction = (now.getFullYear() - lastDeduction.getFullYear()) * 12 + (now.getMonth() - lastDeduction.getMonth())
    else
      monthsSinceLastDeduction = monthsSinceCreation
    
    if monthsSinceLastDeduction >= 1
      deduction = Math.floor(monthsSinceLastDeduction)
      newBalance = @balance - deduction
      
      if newBalance != @balance
        @balance = newBalance
        @lastDeduction = now.toISOString()
        return true
    
    false
  
  # Get status for UI
  getStatus: ->
    if @isLifetime()
      {
        status: 'lifetime'
        balance: 0
        paid: true
        plan: 'lifetime'
        showIndicator: false
      }
    else
      {
        status: if @balance > 0 then 'active' else 'overdue'
        balance: @balance
        paid: @paid
        plan: @plan
        showIndicator: true
        currency: @currency
      }
  
  # Serialization
  toJSON: ->
    {
      __class: 'License'
      createdAt: @createdAt
      balance: @balance
      currency: @currency
      paid: @paid
      plan: @plan
      lastDeduction: @lastDeduction
      activatedAt: @activatedAt
    }
  
  # Deserialize from JSON
  @fromJSON: (data) ->
    return new License() unless data
    license = new License()
    license.createdAt = data.createdAt
    license.balance = data.balance ? License.INITIAL_BALANCE
    license.currency = data.currency ? 'usd'
    license.paid = data.paid ? false
    license.plan = data.plan ? null
    license.lastDeduction = data.lastDeduction ? null
    license.activatedAt = data.activatedAt ? null
    license

  # Migrate from legacy format
  @fromLegacy: (data) ->
    license = new License()
    if data
      license.createdAt = data.createdAt ? new Date().toISOString()
      license.balance = data.balance ? License.INITIAL_BALANCE
      license.currency = data.currency ? 'usd'
      license.paid = data.paid ? false
      license.plan = data.plan ? null
      license.lastDeduction = data.lastDeduction ? null
      license.activatedAt = data.activatedAt ? null
    license

module.exports = { License }
