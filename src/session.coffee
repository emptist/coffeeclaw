# Session class for managing chat conversations
# Each session belongs to a specific bot

class Session
  # Class properties
  @MAX_MESSAGES = 1000
  @MAX_TITLE_LENGTH = 100
  
  constructor: (@id, @botId, @title = 'New Chat') ->
    @messages = []
    @createdAt = new Date().toISOString()
    @updatedAt = @createdAt
    @_messageCount = 0
  
  # Add a message to the session
  addMessage: (role, content, metadata = {}) ->
    # Enforce max messages limit
    if @messages.length >= Session.MAX_MESSAGES
      @messages.shift()  # Remove oldest message
    
    message =
      role: role
      content: content
      timestamp: Date.now()
      metadata: metadata
    
    @messages.push(message)
    @_messageCount++
    @updatedAt = new Date().toISOString()
    
    message
  
  # Add user message
  addUserMessage: (content, metadata = {}) ->
    @addMessage('user', content, metadata)
  
  # Add assistant message
  addAssistantMessage: (content, metadata = {}) ->
    @addMessage('assistant', content, metadata)
  
  # Add system message
  addSystemMessage: (content) ->
    @addMessage('system', content)
  
  # Get message count
  getMessageCount: -> @messages.length
  
  # Get last message
  getLastMessage: ->
    return null if @messages.length == 0
    @messages[@messages.length - 1]
  
  # Get messages by role
  getMessagesByRole: (role) ->
    @messages.filter (m) -> m.role == role
  
  # Get conversation history for API
  getHistoryForAPI: (limit = Session.MAX_MESSAGES) ->
    @messages.slice(-limit).map (m) ->
      { role: m.role, content: m.content }
  
  # Update title
  updateTitle: (title) ->
    if title.length > Session.MAX_TITLE_LENGTH
      title = title.substring(0, Session.MAX_TITLE_LENGTH) + '...'
    @title = title
    @updatedAt = new Date().toISOString()
    this
  
  # Auto-generate title from first user message
  autoGenerateTitle: ->
    firstUserMessage = @messages.find (m) -> m.role == 'user'
    if firstUserMessage
      title = firstUserMessage.content.substring(0, 30)
      title += '...' if firstUserMessage.content.length > 30
      @updateTitle(title)
    this
  
  # Clear all messages
  clear: ->
    @messages = []
    @updatedAt = new Date().toISOString()
    this
  
  # Check if session is empty
  isEmpty: -> @messages.length == 0
  
  # Get session duration in milliseconds
  getDuration: ->
    return 0 if @messages.length < 2
    firstTime = @messages[0].timestamp
    lastTime = @messages[@messages.length - 1].timestamp
    lastTime - firstTime
  
  # Serialization
  toJSON: ->
    {
      __class: 'Session'
      id: @id
      botId: @botId
      title: @title
      messages: @messages
      createdAt: @createdAt
      updatedAt: @updatedAt
      # Note: _messageCount is not saved (can be recalculated)
    }
  
  @fromJSON: (data) ->
    return new Session(null, null, 'Untitled') unless data
    session = new Session(data.id, data.botId, data.title)
    session.messages = data.messages ? []
    session.createdAt = data.createdAt
    session.updatedAt = data.updatedAt
    session._messageCount = session.messages.length
    session

# Session Manager for handling multiple sessions
class SessionManager
  constructor: ->
    @sessions = new Map()
    @activeSessionId = null
  
  # Add a session
  addSession: (session) ->
    @sessions.set(session.id, session)
    this
  
  # Get a session by ID
  getSession: (id) -> @sessions.get(id)
  
  # Get or create session
  getOrCreateSession: (id, botId) ->
    unless @sessions.has(id)
      @sessions.set(id, new Session(id, botId))
    @sessions.get(id)
  
  # Remove a session
  removeSession: (id) ->
    @sessions.delete(id)
    @activeSessionId = null if @activeSessionId == id
    this
  
  # Get all sessions
  getAllSessions: -> Array.from(@sessions.values())
  
  # Get sessions by bot ID
  getSessionsByBot: (botId) ->
    @getAllSessions().filter (s) -> s.botId == botId
  
  # Set active session
  setActiveSession: (id) ->
    @activeSessionId = id
    this
  
  # Get active session
  getActiveSession: ->
    return null unless @activeSessionId
    @sessions.get(@activeSessionId)
  
  # Clear all sessions
  clear: ->
    @sessions.clear()
    @activeSessionId = null
    this
  
  # Serialization
  toJSON: ->
    {
      __class: 'SessionManager'
      sessions: @getAllSessions().map (s) -> s.toJSON()
      activeSessionId: @activeSessionId
    }
  
  @fromJSON: (data) ->
    manager = new SessionManager()
    if data.sessions
      for sessionData in data.sessions
        session = Session.fromJSON(sessionData)
        manager.addSession(session)
    manager.activeSessionId = data.activeSessionId
    manager

module.exports = { Session, SessionManager }
