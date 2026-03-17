import { describe, test, expect, beforeEach } from 'vitest'

const { Session, SessionManager } = require('../src/session.js')

describe('Session', () => {
  let session

  beforeEach(() => {
    session = new Session('test-id', 'bot-1', 'Test Chat')
  })

  test('should create session with default values', () => {
    expect(session.id).toBe('test-id')
    expect(session.botId).toBe('bot-1')
    expect(session.title).toBe('Test Chat')
    expect(session.messages).toEqual([])
    expect(session.createdAt).toBeDefined()
    expect(session.updatedAt).toBeDefined()
  })

  test('should add user message', () => {
    const msg = session.addUserMessage('Hello')
    expect(msg.role).toBe('user')
    expect(msg.content).toBe('Hello')
    expect(msg.timestamp).toBeDefined()
  })

  test('should add assistant message', () => {
    const msg = session.addAssistantMessage('Hi there!')
    expect(msg.role).toBe('assistant')
    expect(msg.content).toBe('Hi there!')
  })

  test('should add system message', () => {
    const msg = session.addSystemMessage('System prompt')
    expect(msg.role).toBe('system')
    expect(msg.content).toBe('System prompt')
  })

  test('should add message with metadata', () => {
    const msg = session.addUserMessage('Test', { source: 'test' })
    expect(msg.metadata).toEqual({ source: 'test' })
  })

  test('should get message count', () => {
    session.addUserMessage('Hello')
    session.addAssistantMessage('Hi')
    expect(session.getMessageCount()).toBe(2)
  })

  test('should get last message', () => {
    session.addUserMessage('First')
    const last = session.addUserMessage('Last')
    expect(session.getLastMessage()).toBe(last)
  })

  test('should get messages by role', () => {
    session.addUserMessage('User 1')
    session.addAssistantMessage('Assistant 1')
    session.addUserMessage('User 2')
    
    const userMessages = session.getMessagesByRole('user')
    expect(userMessages.length).toBe(2)
  })

  test('should get history for API', () => {
    session.addUserMessage('Hello')
    session.addAssistantMessage('Hi')
    
    const history = session.getHistoryForAPI()
    expect(history).toEqual([
      { role: 'user', content: 'Hello' },
      { role: 'assistant', content: 'Hi' }
    ])
  })

  test('should update title', () => {
    session.updateTitle('New Title')
    expect(session.title).toBe('New Title')
  })

  test('should truncate long titles', () => {
    const longTitle = 'a'.repeat(150)
    session.updateTitle(longTitle)
    expect(session.title.length).toBe(103) // 100 + '...'
  })

  test('should auto-generate title from first user message', () => {
    session.addAssistantMessage('Ignore this')
    session.addUserMessage('This is my first message')
    session.autoGenerateTitle()
    expect(session.title).toBe('This is my first message')
  })

  test('should clear messages', () => {
    session.addUserMessage('Hello')
    session.addAssistantMessage('Hi')
    session.clear()
    expect(session.messages.length).toBe(0)
  })

  test('should check if empty', () => {
    expect(session.isEmpty()).toBe(true)
    session.addUserMessage('Hello')
    expect(session.isEmpty()).toBe(false)
  })

  test('should serialize to JSON', () => {
    const json = session.toJSON()
    expect(json.__class).toBe('Session')
    expect(json.id).toBe('test-id')
    expect(json.botId).toBe('bot-1')
  })

  test('should deserialize from JSON', () => {
    const data = {
      id: 'session-1',
      botId: 'bot-1',
      title: 'Test',
      messages: [
        { role: 'user', content: 'Hello', timestamp: 123 }
      ],
      createdAt: '2024-01-01',
      updatedAt: '2024-01-02'
    }
    const restored = Session.fromJSON(data)
    expect(restored.id).toBe('session-1')
    expect(restored.messages.length).toBe(1)
  })

  test('should handle null/undefined in fromJSON', () => {
    const session1 = Session.fromJSON(null)
    expect(session1.id).toBeNull()
    
    const session2 = Session.fromJSON(undefined)
    expect(session2.title).toBe('Untitled')
  })

  test('should enforce max messages limit', () => {
    // MAX_MESSAGES is 1000, so we test with smaller number by temporarily overriding
    const originalMax = Session.MAX_MESSAGES
    Session.MAX_MESSAGES = 3
    
    session.addUserMessage('1')
    session.addUserMessage('2')
    session.addUserMessage('3')
    session.addUserMessage('4') // Should remove oldest
    
    expect(session.messages.length).toBe(3)
    expect(session.messages[0].content).toBe('2')
    
    Session.MAX_MESSAGES = originalMax
  })

  test('should calculate duration', () => {
    session.addUserMessage('Hello')
    // Simulate time passing
    session.messages[0].timestamp = 1000
    session.addAssistantMessage('Hi')
    session.messages[1].timestamp = 5000
    
    expect(session.getDuration()).toBe(4000)
  })
})

describe('SessionManager', () => {
  let manager

  beforeEach(() => {
    manager = new SessionManager()
  })

  test('should create empty manager', () => {
    expect(manager.sessions.size).toBe(0)
    expect(manager.activeSessionId).toBeNull()
  })

  test('should add session', () => {
    const session = new Session('1', 'bot-1')
    manager.addSession(session)
    expect(manager.sessions.size).toBe(1)
  })

  test('should get session by ID', () => {
    const session = new Session('1', 'bot-1')
    manager.addSession(session)
    expect(manager.getSession('1')).toBe(session)
  })

  test('should get or create session', () => {
    const session = manager.getOrCreateSession('1', 'bot-1')
    expect(session).toBeDefined()
    expect(session.id).toBe('1')
    
    // Should return existing
    const same = manager.getOrCreateSession('1', 'bot-1')
    expect(session).toBe(same)
  })

  test('should remove session', () => {
    const session = new Session('1', 'bot-1')
    manager.addSession(session)
    manager.removeSession('1')
    expect(manager.sessions.size).toBe(0)
  })

  test('should get all sessions', () => {
    manager.addSession(new Session('1', 'bot-1'))
    manager.addSession(new Session('2', 'bot-1'))
    const all = manager.getAllSessions()
    expect(all.length).toBe(2)
  })

  test('should get sessions by bot', () => {
    manager.addSession(new Session('1', 'bot-1'))
    manager.addSession(new Session('2', 'bot-2'))
    manager.addSession(new Session('3', 'bot-1'))
    
    const bot1Sessions = manager.getSessionsByBot('bot-1')
    expect(bot1Sessions.length).toBe(2)
  })

  test('should set and get active session', () => {
    const session = new Session('1', 'bot-1')
    manager.addSession(session)
    manager.setActiveSession('1')
    expect(manager.getActiveSession()).toBe(session)
  })

  test('should return null for non-existent active session', () => {
    manager.setActiveSession('non-existent')
    expect(manager.getActiveSession()).toBeNull()
  })

  test('should clear all sessions', () => {
    manager.addSession(new Session('1', 'bot-1'))
    manager.setActiveSession('1')
    manager.clear()
    expect(manager.sessions.size).toBe(0)
    expect(manager.activeSessionId).toBeNull()
  })

  test('should serialize to JSON', () => {
    manager.addSession(new Session('1', 'bot-1', 'Chat 1'))
    manager.setActiveSession('1')
    
    const json = manager.toJSON()
    expect(json.__class).toBe('SessionManager')
    expect(json.sessions.length).toBe(1)
    expect(json.activeSessionId).toBe('1')
  })

  test('should deserialize from JSON', () => {
    const data = {
      sessions: [
        { id: '1', botId: 'bot-1', title: 'Chat', messages: [], createdAt: '', updatedAt: '' }
      ],
      activeSessionId: '1'
    }
    
    const restored = SessionManager.fromJSON(data)
    expect(restored.sessions.size).toBe(1)
    expect(restored.activeSessionId).toBe('1')
  })
})
