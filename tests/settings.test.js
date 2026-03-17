import { describe, test, expect, beforeEach, vi } from 'vitest'

const { Settings } = require('../src/settings.js')

describe('Settings', () => {
  let settings

  beforeEach(() => {
    settings = new Settings()
  })

  test('should create settings with default values', () => {
    expect(settings.token).toBeNull()
    expect(settings.apiKey).toBe('')
    expect(settings.model).toBe('GLM-4-Flash')
    expect(settings.provider).toBe('zhipu')
    expect(settings.providers).toEqual({})
    expect(settings.activeProvider).toBe('zhipu')
  })

  test('should set API key', () => {
    settings.setAPIKey('test-key-123')
    expect(settings.apiKey).toBe('test-key-123')
  })

  test('should set token', () => {
    settings.setToken('test-token')
    expect(settings.token).toBe('test-token')
  })

  test('should set provider', () => {
    settings.setProvider('openai', 'key-123', 'gpt-4o')
    expect(settings.providers.openai).toBeDefined()
    expect(settings.providers.openai.apiKey).toBe('key-123')
    expect(settings.providers.openai.model).toBe('gpt-4o')
    expect(settings.activeProvider).toBe('openai')
  })

  test('should serialize to JSON', () => {
    settings.setAPIKey('test-key')
    settings.setToken('test-token')
    const json = settings.toJSON()
    expect(json.__class).toBe('Settings')
    expect(json.apiKey).toBe('test-key')
    expect(json.token).toBe('test-token')
    expect(json._lastUpdated).toBeDefined()
  })

  test('should deserialize from JSON', () => {
    const data = {
      __class: 'Settings',
      apiKey: 'restored-key',
      token: 'restored-token',
      model: 'GLM-4-Flash',
      provider: 'zhipu',
      providers: {},
      activeProvider: 'zhipu',
      _lastUpdated: '2024-01-01T00:00:00.000Z'
    }
    const restored = Settings.fromJSON(data)
    expect(restored.apiKey).toBe('restored-key')
    expect(restored.token).toBe('restored-token')
  })

  test('should handle null/undefined in fromJSON', () => {
    const settings1 = Settings.fromJSON(null)
    expect(settings1.apiKey).toBe('')
    
    const settings2 = Settings.fromJSON(undefined)
    expect(settings2.model).toBe('GLM-4-Flash')
  })

  test('should update lastUpdated on changes', () => {
    const before = settings._lastUpdated
    settings.setAPIKey('new-key')
    expect(settings._lastUpdated).toBeGreaterThan(before)
  })
})
