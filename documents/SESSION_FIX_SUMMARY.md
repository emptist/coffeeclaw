# Session Saving Fix - Implementation Summary

## Changes Made

### 1. Modified `src/openclaw-manager.coffee`

**Before:**
```coffee
if isAgent
  @storage.addAgentMessage(sessionId, 'user', message)
  response = await @callAPI(sessionId, message, settings, bot)
  @storage.addAgentMessage(sessionId, 'assistant', response)
else
  @storage.addMessage(sessionId, 'user', message)
  response = await @callAPI(sessionId, message, settings, bot)
  @storage.addMessage(sessionId, 'assistant', response)
```

**After:**
```coffee
# Use regular session storage for all messages (including agent)
# Add metadata to distinguish agent messages
metadata = if isAgent then { source: 'openclaw-agent' } else {}

@storage.addMessage(sessionId, 'user', message, metadata)
response = await @callAPI(sessionId, message, settings, bot)
@storage.addMessage(sessionId, 'assistant', response, metadata)
```

**Impact:**
- All messages (agent + regular) now stored in same session storage
- Agent messages tagged with `{ source: 'openclaw-agent' }` metadata
- No more separate `agentSessions` storage for new conversations

### 2. Modified `src/core/typed-storage.coffee`

**Before:**
```coffee
addMessage: (sessionId, role, content) ->
  session = @getSession(sessionId)
  session.addMessage(role, content)
  ...
```

**After:**
```coffee
addMessage: (sessionId, role, content, metadata = {}) ->
  session = @getSession(sessionId)
  session.addMessage(role, content, metadata)
  ...
```

**Impact:**
- `addMessage` now accepts optional metadata parameter
- Metadata stored with each message
- Backward compatible (defaults to empty object)

### 3. No Changes Needed to `src/session.coffee`

The Session class already supported metadata:
```coffee
addMessage: (role, content, metadata = {}) ->
  message =
    role: role
    content: content
    timestamp: Date.now()
    metadata: metadata
  @messages.push(message)
```

## Benefits

✅ **Unified Session Storage**
- All conversations in one place
- Simpler architecture
- Single source of truth

✅ **Agent Conversations Visible**
- Agent sessions now appear in left pane
- Can review agent conversation history
- Can switch between agent and regular sessions

✅ **Metadata Preservation**
- Agent messages tagged with `{ source: 'openclaw-agent' }`
- Can distinguish agent vs regular messages
- Future features can use metadata (filtering, icons, etc.)

✅ **Backward Compatible**
- Existing sessions continue to work
- Metadata defaults to empty object
- No data loss

## Testing Checklist

After restart:
- [ ] Send message to regular bot → appears in session list
- [ ] Send message to agent bot → appears in session list
- [ ] Switch between sessions works
- [ ] Delete session works
- [ ] Agent messages have metadata
- [ ] Regular messages have empty metadata

## Migration Note

**Old agent sessions** (in `agentSessions` storage) will not appear in the list initially. They remain in storage but are not displayed.

**Options:**
1. Accept this (new sessions will work correctly)
2. Implement migration script to move old agent sessions to regular sessions
3. Add dual-listing feature (show both old and new)

## Next Step

Run the config fix script to eliminate duplicate plugin warnings:

```bash
./scripts/fix_openclaw_config.sh
```

This will:
- Remove duplicate feishu plugin entry
- Add plugin whitelist
- Create backup automatically
