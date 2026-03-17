import { describe, test, expect, beforeEach } from 'vitest'

const { License } = require('../src/license.js')

describe('License', () => {
  let license

  beforeEach(() => {
    license = new License()
  })

  test('should create license with default values', () => {
    expect(license.plan).toBe('free')
    expect(license.balance).toBe(0)
    expect(license.paid).toBe(false)
    expect(license.paymentInfo).toEqual([])
  })

  test('should check free plan status', () => {
    const status = license.getStatus()
    expect(status.plan).toBe('free')
    expect(status.paid).toBe(false)
    expect(status.balance).toBe(0)
  })

  test('should add payment', () => {
    license.addPayment(100, 'stripe', 'test@example.com', 'usd')
    expect(license.balance).toBe(100)
    expect(license.paid).toBe(true)
    expect(license.paymentInfo.length).toBe(1)
    expect(license.paymentInfo[0].amount).toBe(100)
  })

  test('should set lifetime plan for large payment', () => {
    license.addPayment(50, 'stripe', 'test@example.com', 'usd')
    expect(license.plan).toBe('free')
    
    license.addPayment(40, 'stripe', 'test@example.com', 'usd')  // Now 90 total
    expect(license.plan).toBe('free')
    
    license.addPayment(10, 'stripe', 'test@example.com', 'usd')  # Now 100 total
    expect(license.plan).toBe('lifetime')
  })

  test('should serialize to JSON', () => {
    license.addPayment(100, 'stripe', 'test@example.com')
    const json = license.toJSON()
    expect(json.__class).toBe('License')
    expect(json.balance).toBe(100)
    expect(json.plan).toBe('lifetime')
  })

  test('should deserialize from JSON', () => {
    const data = {
      __class: 'License',
      plan: 'lifetime',
      balance: 500,
      paid: true,
      currency: 'usd',
      activatedAt: '2024-01-01T00:00:00.000Z',
      paymentInfo: [{ amount: 500, method: 'stripe', email: 'test@example.com' }]
    }
    const restored = License.fromJSON(data)
    expect(restored.plan).toBe('lifetime')
    expect(restored.balance).toBe(500)
    expect(restored.activatedAt).toBe('2024-01-01T00:00:00.000Z')
  })

  test('should handle null/undefined in fromJSON', () => {
    const license1 = License.fromJSON(null)
    expect(license1.plan).toBe('free')
    
    const license2 = License.fromJSON(undefined)
    expect(license2.balance).toBe(0)
  })

  test('should validate currency mismatch', () => {
    license.addPayment(100, 'stripe', 'test@example.com', 'cny')
    const result = license.validatePayment(50, 'usd')
    expect(result.valid).toBe(false)
    expect(result.error).toContain('Currency mismatch')
  })
})
