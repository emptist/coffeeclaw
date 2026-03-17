# Test suite for License class

{ License } = require '../src/license'

describe 'License', ->
  describe 'Creation', ->
    it 'should create with default values', ->
      license = new License()
      license.balance.should.equal License.INITIAL_BALANCE
      license.currency.should.equal 'usd'
      license.paid.should.be.false
      license.plan.should.be.null
      license.lastDeduction.should.be.null

  describe 'Balance Management', ->
    it 'should get balance', ->
      license = new License()
      license.getBalance().should.equal License.INITIAL_BALANCE

    it 'should add balance', ->
      license = new License()
      license.addBalance(10)
      license.balance.should.equal 11
      license.paid.should.be.true

    it 'should set plan', ->
      license = new License()
      license.setPlan('monthly', 10)
      license.plan.should.equal 'monthly'
      license.paid.should.be.true

    it 'should set lifetime plan', ->
      license = new License()
      license.setPlan('lifetime', 50)
      license.plan.should.equal 'lifetime'
      license.balance.should.equal 0

  describe 'Status Checks', ->
    it 'should check if lifetime', ->
      license = new License()
      license.isLifetime().should.be.false
      license.setPlan('lifetime', 50)
      license.isLifetime().should.be.true

    it 'should check if active - lifetime', ->
      license = new License()
      license.setPlan('lifetime', 50)
      license.isActive().should.be.true

    it 'should check if active - with balance', ->
      license = new License()
      license.balance = 5
      license.isActive().should.be.true

    it 'should check if active - no balance', ->
      license = new License()
      license.balance = 0
      license.isActive().should.be.false

  describe 'Monthly Deduction', ->
    it 'should not deduct for lifetime license', ->
      license = new License()
      license.setPlan('lifetime', 50)
      result = license.processMonthlyDeduction()
      result.should.be.false

    it 'should not deduct if no balance', ->
      license = new License()
      license.balance = 0
      result = license.processMonthlyDeduction()
      result.should.be.false

    it 'should deduct monthly for active license', ->
      license = new License()
      license.createdAt = new Date(Date.now() - 31 * 24 * 60 * 60 * 1000).toISOString()
      license.balance = 5
      result = license.processMonthlyDeduction()
      result.should.be.true
      license.balance.should.equal 4

    it 'should not deduct if less than a month has passed', ->
      license = new License()
      license.balance = 5
      result = license.processMonthlyDeduction()
      result.should.be.false
      license.balance.should.equal 5

  describe 'Status', ->
    it 'should return lifetime status', ->
      license = new License()
      license.setPlan('lifetime', 50)
      status = license.getStatus()
      status.status.should.equal 'lifetime'
      status.balance.should.equal 0
      status.paid.should.be.true
      status.plan.should.equal 'lifetime'

    it 'should return active status when has balance', ->
      license = new License()
      license.balance = 5
      status = license.getStatus()
      status.status.should.equal 'active'
      status.balance.should.equal 5
      status.showIndicator.should.be.true

    it 'should return overdue status when no balance', ->
      license = new License()
      license.balance = 0
      status = license.getStatus()
      status.status.should.equal 'overdue'
      status.balance.should.equal 0
      status.showIndicator.should.be.true

  describe 'Serialization', ->
    it 'should serialize to JSON', ->
      license = new License()
      license.balance = 10
      license.setPlan('monthly')
      json = license.toJSON()
      json.__class.should.equal 'License'
      json.balance.should.equal 10
      json.plan.should.equal 'monthly'
      json.currency.should.equal 'usd'

    it 'should deserialize from JSON', ->
      json = {
        __class: 'License'
        createdAt: '2024-01-01T00:00:00.000Z'
        balance: 10
        currency: 'usd'
        paid: true
        plan: 'monthly'
        lastDeduction: null
      }
      license = License.fromJSON(json)
      license.balance.should.equal 10
      license.plan.should.equal 'monthly'
      license.paid.should.be.true

    it 'should handle null data in fromJSON', ->
      license = License.fromJSON(null)
      license.balance.should.equal License.INITIAL_BALANCE

  describe 'Legacy Migration', ->
    it 'should migrate from legacy format', ->
      legacyData = {
        createdAt: '2024-01-01T00:00:00.000Z'
        balance: 15
        currency: 'cny'
        paid: true
        plan: 'lifetime'
      }
      license = License.fromLegacy(legacyData)
      license.balance.should.equal 15
      license.currency.should.equal 'cny'
      license.plan.should.equal 'lifetime'

    it 'should use defaults for missing legacy data', ->
      license = License.fromLegacy(null)
      license.balance.should.equal License.INITIAL_BALANCE
