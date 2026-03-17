# Test suite for Session classes

{ Session, SessionManager } = require '../src/session'

describe 'Session', ->
  describe 'Session Creation', ->
    it 'should create a session with default values', ->
      session = new Session('test-id', 'bot-1', 'Test Chat')
      session.id.should.equal 'test-id'
      session.botId.should.equal 'bot-1'
      session.title.should.equal 'Test Chat'
      session.messages.length.should.equal 0

    it 'should create session with default title', ->
      session = new Session('test-id', 'bot-1')
      session.title.should.equal 'New Chat'

  describe 'Message Management', ->
    it 'should add user message', ->
      session = new Session('test-id', 'bot-1')
      msg = session.addUserMessage('Hello')
      msg.role.should.equal 'user'
      msg.content.should.equal 'Hello'
      session.messages.length.should.equal 1

    it 'should add assistant message', ->
      session = new Session('test-id', 'bot-1')
      msg = session.addAssistantMessage('Hi there')
      msg.role.should.equal 'assistant'
      msg.content.should.equal 'Hi there'

    it 'should add system message', ->
      session = new Session('test-id', 'bot-1')
      msg = session.addSystemMessage('System note')
      msg.role.should.equal 'system'

    it 'should enforce max messages limit', ->
      session = new Session('test-id', 'bot-1')
      # Add MAX_MESSAGES + 1 messages
      for i in [0..Session.MAX_MESSAGES]
        session.addMessage('user', "Message #{i}")
      # Should have MAX_MESSAGES messages (oldest removed)
      session.messages.length.should.equal Session.MAX_MESSAGES

    it 'should get last message', ->
      session = new Session('test-id', 'bot-1')
      session.addUserMessage('First')
      session.addAssistantMessage('Second')
      last = session.getLastMessage()
      last.content.should.equal 'Second'

    it 'should get messages by role', ->
      session = new Session('test-id', 'bot-1')
      session.addUserMessage('User 1')
      session.addAssistantMessage('Bot 1')
      session.addUserMessage('User 2')
      userMsgs = session.getMessagesByRole('user')
      userMsgs.length.should.equal 2

    it 'should get history for API', ->
      session = new Session('test-id', 'bot-1')
      session.addUserMessage('Hello')
      session.addAssistantMessage('Hi')
      history = session.getHistoryForAPI()
      history.length.should.equal 2
      history[0].role.should.equal 'user'
      history[1].role.should.equal 'assistant'

  describe 'Title Management', ->
    it 'should update title', ->
      session = new Session('test-id', 'bot-1')
      session.updateTitle('New Title')
      session.title.should.equal 'New Title'

    it 'should truncate long titles', ->
      session = new Session('test-id', 'bot-1')
      longTitle = 'a'.repeat(150)
      session.updateTitle(longTitle)
      session.title.length.should.equal 103 # 100 + '...'

    it 'should auto-generate title from first user message', ->
      session = new Session('test-id', 'bot-1')
      session.addUserMessage('This is my first question about something')
      session.autoGenerateTitle()
      session.title.should.equal 'This is my first question abo...'

  describe 'Serialization', ->
    it 'should serialize to JSON', ->
      session = new Session('test-id', 'bot-1', 'Test')
      session.addUserMessage('Hello')
      json = session.toJSON()
      json.__class.should.equal 'Session'
      json.id.should.equal 'test-id'
      json.botId.should.equal 'bot-1'
      json.title.should.equal 'Test'
      json.messages.length.should.equal 1

    it 'should deserialize from JSON', ->
      json = {
        __class: 'Session'
        id: 'test-id'
        botId: 'bot-1'
        title: 'Test Chat'
        messages: [{ role: 'user', content: 'Hello', timestamp: 1234567890, metadata: {} }]
        createdAt: '2024-01-01T00:00:00.000Z'
        updatedAt: '2024-01-01T00:00:00.000Z'
      }
      session = Session.fromJSON(json)
      session.id.should.equal 'test-id'
      session.botId.should.equal 'bot-1'
      session.title.should.equal 'Test Chat'
      session.messages.length.should.equal 1
      session.messages[0].content.should.equal 'Hello'

    it 'should handle null data in fromJSON', ->
      session = Session.fromJSON(null)
      session.id.should.be.null

describe 'SessionManager', ->
  describe 'Session Management', ->
    it 'should add session', ->
      manager = new SessionManager()
      session = new Session('test-id', 'bot-1')
      manager.addSession(session)
      manager.getSession('test-id').should.equal session

    it 'should get or create session', ->
      manager = new SessionManager()
      session = manager.getOrCreateSession('test-id', 'bot-1')
      session.id.should.equal 'test-id'
      session.botId.should.equal 'bot-1'
      # Should return existing session
      session2 = manager.getOrCreateSession('test-id', 'bot-2')
      session2.id.should.equal session.id

    it 'should remove session', ->
      manager = new SessionManager()
      session = new Session('test-id', 'bot-1')
      manager.addSession(session)
      manager.removeSession('test-id')
      (manager.getSession('test-id')).should.be.undefined

    it 'should get all sessions', ->
      manager = new SessionManager()
      manager.addSession(new Session('id1', 'bot-1'))
      manager.addSession(new Session('id2', 'bot-1'))
      manager.getAllSessions().length.should.equal 2

    it 'should get sessions by bot', ->
      manager = new SessionManager()
      manager.addSession(new Session('id1', 'bot-1'))
      manager.addSession(new Session('id2', 'bot-2'))
      manager.addSession(new Session('id3', 'bot-1'))
      sessions = manager.getSessionsByBot('bot-1')
      sessions.length.should.equal 2

  describe 'Active Session', ->
    it 'should set and get active session', ->
      manager = new SessionManager()
      session = new Session('test-id', 'bot-1')
      manager.addSession(session)
      manager.setActiveSession('test-id')
      manager.getActiveSession().should.equal session

    it 'should return null for active session when not set', ->
      manager = new SessionManager()
      (manager.getActiveSession()).should.be.null

  describe 'Serialization', ->
    it 'should serialize to JSON', ->
      manager = new SessionManager()
      session = new Session('test-id', 'bot-1', 'Test')
      session.addUserMessage('Hello')
      manager.addSession(session)
      json = manager.toJSON()
      json.__class.should.equal 'SessionManager'
      json.sessions.length.should.equal 1

    it 'should deserialize from JSON', ->
      json = {
        __class: 'SessionManager'
        sessions: [{
          __class: 'Session'
          id: 'test-id'
          botId: 'bot-1'
          title: 'Test'
          messages: []
          createdAt: '2024-01-01T00:00:00.000Z'
          updatedAt: '2024-01-01T00:00:00.000Z'
        }]
        activeSessionId: 'test-id'
      }
      manager = SessionManager.fromJSON(json)
      manager.getAllSessions().length.should.equal 1
      manager.activeSessionId.should.equal 'test-id'
