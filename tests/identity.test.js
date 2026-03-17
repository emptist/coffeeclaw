import { describe, test, expect, beforeEach } from 'vitest'

const { Identity } = require('../src/identity.js')

describe('Identity', () => {
  let identity

  beforeEach(() => {
    identity = new Identity()
  })

  test('should create default identity', () => {
    expect(identity.id).toBeDefined()
    expect(identity.name).toBe('')
    expect(identity.email).toBe('')
    expect(identity.avatar).toBe('')
  })

  test('should create identity with id', () => {
    const id = new Identity('custom-id')
    expect(id.id).toBe('custom-id')
  })

  test('should update identity properties', () => {
    identity.name = 'Test User'
    identity.email = 'test@example.com'
    identity.avatar = 'https://example.com/avatar.png'

    expect(identity.name).toBe('Test User')
    expect(identity.email).toBe('test@example.com')
    expect(identity.avatar).toBe('https://example.com/avatar.png')
  })

  test('should serialize to JSON', () => {
    identity.name = 'Test'
    const json = identity.toJSON()

    expect(json.__class).toBe('Identity')
    expect(json.name).toBe('Test')
  })

  test('should deserialize from JSON', () => {
    const data = {
      __class: 'Identity',
      id: 'test-id',
      name: 'Test User',
      email: 'test@example.com',
      avatar: 'https://example.com/avatar.png',
    }

    const restored = Identity.fromJSON(data)
    expect(restored.id).toBe('test-id')
    expect(restored.name).toBe('Test User')
    expect(restored.email).toBe('test@example.com')
  })

  test('should handle null/undefined in fromJSON', () => {
    const identity1 = Identity.fromJSON(null)
    expect(identity1).toBeDefined()
    expect(identity1.id).toBeDefined()

    const identity2 = Identity.fromJSON(undefined)
    expect(identity2).toBeDefined()
  })

  test('should create from string', () => {
    const data = JSON.stringify({
      id: 'test-id',
      name: 'Test',
      email: 'test@test.com',
    })

    const id = Identity.fromString(data)
    expect(id.id).toBe('test-id')
    expect(id.name).toBe('Test')
  })
})
