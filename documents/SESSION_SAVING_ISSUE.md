# Session Saving Issue Analysis

## Problem

When using OpenClaw Agent in CoffeeClaw GUI, conversations are not appearing in the left pane session list.

## Root Cause

### Two Separate Session Systems

**Regular Sessions:**
- Stored in: `sessions` key in electron-store
- Managed by: `SessionManager` class
- UI displays: Left pane session list
- IPC handler: `list-sessions` → `storage.listSessions()`

**Agent Sessions:**
- Stored in: `agentSessions` key in electron-store
- Managed by: Plain JavaScript objects
- UI displays: **NOT IMPLEMENTED**
- IPC handler: `list-agent-sessions` → `storage.listAgentSessions()`

### Code Flow

**When using OpenClaw Agent:**

1. User sends message in GUI
2. [openclaw-manager.coffee:212-214](file:///Users/jk/gits/hub/tools_ai/coffeeclaw/src/openclaw-manager.coffee#L212-214):
   ```coffee
   @storage.addAgentMessage(sessionId, 'user', message)
   response = await @callAPI(sessionId, message, settings, bot)
   @storage.addAgentMessage(sessionId, 'assistant', response)
   ```

3. Messages saved to `agentSessions` storage
4. UI calls `window.api.listSessions()` (regular sessions)
5. Agent sessions not displayed ❌

**When using Regular Bot:**

1. User sends message in GUI
2. [openclaw-manager.coffee:216-218](file:///Users/jk/gits/hub/tools_ai/coffeeclaw/src/openclaw-manager.coffee#L216-218):
   ```coffee
   @storage.addMessage(sessionId, 'user', message)
   response = await @callAPI(sessionId, message, settings, bot)
   @storage.addMessage(sessionId, 'assistant', response)
   ```

3. Messages saved to `sessions` storage
4. UI calls `window.api.listSessions()`
5. Sessions displayed in left pane ✅

## Solution Options

### Option 1: Merge Agent Sessions into Regular Sessions (Recommended)

**Pros:**
- Single source of truth for all sessions
- No UI changes needed
- Simpler architecture

**Cons:**
- Need to ensure agent session data format matches regular sessions

**Implementation:**
```coffee
# In openclaw-manager.coffee
sendMessage: (sessionId, message, settings, bot = null) ->
  # Always use regular session storage
  @storage.addMessage(sessionId, 'user', message)
  response = await @callAPI(sessionId, message, settings, bot)
  @storage.addMessage(sessionId, 'assistant', response)
  response
```

### Option 2: Add Agent Sessions to UI

**Pros:**
- Keeps separation between agent and regular sessions
- Could show different icons/indicators

**Cons:**
- More complex UI
- Two separate lists to manage
- User confusion about which session is which

**Implementation:**
- Add new UI section for agent sessions
- Call `window.api.listAgentSessions()` separately
- Merge both lists in UI

### Option 3: Hybrid - Tag Sessions as Agent Sessions

**Pros:**
- Single session list in UI
- Can show visual indicator for agent sessions
- Maintains session continuity

**Cons:**
- Need to add metadata to sessions

**Implementation:**
```coffee
# Add metadata to session
session.addMessage('user', message, { source: 'agent' })
session.addMessage('assistant', response, { source: 'agent' })
```

## Recommended Solution: Option 1

Merge agent sessions into regular sessions for simplicity and consistency.

### Changes Required

1. **Remove agent session storage** from openclaw-manager.coffee
2. **Use regular session storage** for all messages
3. **Keep agent session metadata** in message metadata if needed
4. **Remove agentSessions** from TypedStorage (or keep for backward compatibility)

### Testing

After fix:
- [ ] Agent conversations appear in left pane
- [ ] Regular bot conversations still work
- [ ] Session switching works correctly
- [ ] Session deletion works correctly
- [ ] No data loss during migration

## Current Status

- ✅ Agent can write files (using OpenRouter)
- ✅ Agent responds correctly
- ❌ Agent sessions not visible in UI
- ❌ No session history for agent conversations
