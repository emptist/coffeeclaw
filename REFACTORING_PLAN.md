# CoffeeClaw Refactoring Plan

## Executive Summary

This document outlines a comprehensive plan to improve CoffeeClaw's codebase through modularization, modernization, and quality improvements.

**Current State:**
- `main.coffee`: 1555 lines (god object)
- 42 IPC handlers in single file
- Mixed storage (TypedStorage + direct fs)
- No tests

**Target State:**
- Modular architecture with clear separation
- ~300 lines in main.coffee
- Comprehensive test coverage
- Modern build tooling

---

## Phase 1: Complete Modularization

### 1.1 Extract IPC Handlers

**Goal:** Move all 42 IPC handlers to separate modules.

**Current Structure:**
```coffeescript
ipcMain.handle 'send-message', (event, sessionId, message) ->
ipcMain.handle 'get-settings', ->
ipcMain.handle 'save-settings', (event, newSettings) ->
# ... 39 more handlers
```

**Target Structure:**
```
src/
├── main.coffee           # App entry, window creation, startup
├── ipc/
│   ├── index.coffee     # Register all handlers
│   ├── session.coffee   # Session-related handlers
│   ├── bot.coffee       # Bot-related handlers
│   ├── settings.coffee  # Settings handlers
│   ├── license.coffee   # License handlers
│   ├── system.coffee   # System check, prerequisites
│   ├── openclaw.coffee # OpenClaw integration
│   ├── feishu.coffee   # Feishu integration
│   └── backup.coffee   # Backup/restore handlers
```

**Handler Mapping:**

| Current | New Module |
|---------|------------|
| send-message, get-session, list-sessions, delete-session, add-message, create-session, get-history, clear-history | session.coffee |
| get-bots, get-bot, get-active-bot, create-bot, update-bot, delete-bot, set-active-bot, get-bot-templates, export-bots, import-bots | bot.coffee |
| get-settings, save-settings, get-models | settings.coffee |
| get-license, get-license-prices, activate-license, add-payment | license.coffee |
| check-status, check-prerequisites, run-setup, has-backup | system.coffee |
| backup-settings, list-backups, restore-backup, get-backup-data, export-all-settings, import-all-settings | backup.coffee |
| get-feishu-status, sync-feishu-to-openclaw, approve-feishu-pairing | feishu.coffee |
| call-openclaw-agent, get-agent-session, list-agent-sessions | openclaw.coffee |
| open-external, run-local-command | system.coffee |

**Implementation:**
1. Create `src/ipc/` directory
2. Create each module with handler functions
3. Create `src/ipc/index.coffee` to register all handlers
4. Update main.coffee to import and register

---

### 1.2 Extract AI API Layer

**Goal:** Separate API calling logic from IPC handlers.

**Current:**
```coffeescript
callAPI = (sessionId, message, settings, bot = null) ->
  # ... 100+ lines of API logic
```

**Target Structure:**
```
src/
├── api/
│   ├── index.coffee     # Main API interface
│   ├── base.coffee      # Base API client
│   ├── zhipu.coffee    # Zhipu-specific logic
│   ├── openrouter.coffee # OpenRouter-specific logic
│   └── tools.coffee    # Tool execution
```

**Functions to Extract:**
- `callAPI()` - Main API entry
- `callAPIWithMessages()` - Recursive tool calling
- `callOpenClawAgent()` - OpenClaw CLI integration
- `executeSkillFunction()` - Tool execution

---

### 1.3 Extract Skill Handlers

**Goal:** Clean up the SKILLS object and make extensible.

**Current:**
```coffeescript
SKILLS =
  fs:
    list_files: ...
    read_file: ...
  code:
    execute: ...
  git:
    status: ...
    log: ...
```

**Target:**
```
src/
├── skills/
│   ├── index.coffee     # Skill registry
│   ├── fs.coffee       # File system skills
│   ├── code.coffee     # Code execution skills
│   ├── git.coffee      # Git skills
│   └── registry.coffee # Skill registration
```

---

## Phase 2: Modernize Build System

### 2.1 Add ESLint

```bash
npm install --save-dev eslint
```

Create `.eslintrc.json`:
```json
{
  "env": {
    "es2021": true,
    "node": true
  },
  "extends": "eslint:recommended",
  "parserOptions": {
    "ecmaVersion": 2021
  }
}
```

### 2.2 Add Unit Tests

```bash
npm install --save-dev mocha chai
```

Create `test/` directory:
```
test/
├── api/
├── skills/
├── storage/
└── main.test.coffee
```

### 2.3 Add GitHub Actions CI

Create `.github/workflows/test.yml`:
```yaml
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
      - run: npm install
      - run: npm run compile
      - run: npm test
```

---

## Phase 3: Security & Stability

### 3.1 Sandbox Command Execution

**Current Risk:**
```coffeescript
ALLOWED_COMMANDS = ['ls', 'git', 'npm', 'node', ...]
```

**Improvements:**
1. Remove dangerous commands: `curl`, `wget`, `grep`, `find`
2. Add timeout enforcement
3. Add output size limits
4. Consider Docker sandbox for advanced execution

### 3.2 Add Error Handling

```coffeescript
# Add global error handler
process.on 'uncaughtException', (error) ->
  console.error 'Uncaught Exception:', error
  # Log to file

process.on 'unhandledRejection', (reason) ->
  console.error 'Unhandled Rejection:', reason
```

### 3.3 Structured Logging

```coffeescript
class Logger
  @level: 'info'
  @log: (level, message, data) ->
    # Write to file with timestamp
```

---

## Phase 4: Technical Debt

### 4.1 Consolidate Storage

**Current Issues:**
- TypedStorage for settings, bots, sessions, license
- Direct fs for agent-sessions, backups
- Direct fs for OpenClaw config

**Solution:**
- Migrate all to TypedStorage
- Or create unified Storage interface

### 4.2 Standardize Error Responses

**Current:**
```coffeescript
return { error: 'Bot name is required' }
return null
throw new Error(...)
```

**Standard:**
```coffeescript
{ success: false, error: { code: 'INVALID_NAME', message: '...' } }
{ success: true, data: { ... } }
```

### 4.3 Update Documentation

- Update DEVELOPER_GUIDE.md
- Update ARCHITECTURE.md
- Add API documentation
- Add contribution guidelines

---

## Implementation Order

### Sprint 1: IPC Extraction
- [ ] Create `src/ipc/` directory
- [ ] Create `src/ipc/index.coffee`
- [ ] Extract session handlers
- [ ] Extract bot handlers
- [ ] Extract settings handlers
- [ ] Extract license handlers
- [ ] Extract remaining handlers
- [ ] Test all IPC calls

### Sprint 2: API Layer
- [ ] Create `src/api/` directory
- [ ] Extract callAPI functions
- [ ] Extract OpenClaw agent calls
- [ ] Extract skill execution
- [ ] Test API layer

### Sprint 3: Skills & Storage
- [ ] Create `src/skills/` directory
- [ ] Refactor SKILLS to module pattern
- [ ] Consolidate storage operations
- [ ] Test storage layer

### Sprint 4: Quality
- [ ] Add ESLint config
- [ ] Add basic tests
- [ ] Add CI workflow
- [ ] Fix lint errors
- [ ] Update documentation

---

## Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| main.coffee lines | 1555 | <300 |
| IPC handlers in main | 42 | 0 |
| Test coverage | 0% | >50% |
| ESLint errors | N/A | 0 |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking IPC during refactor | High | Test each handler after extraction |
| Losing functionality | High | Keep main.coffee as thin wrapper |
| Time investment | Medium | Phase approach allows stopping points |
| Test complexity | Medium | Start with integration tests |

---

## Appendix: File Structure After Refactoring

```
coffeeclaw/
├── src/
│   ├── main.coffee              # Entry point (~200 lines)
│   ├── preload.coffee           # Preload script
│   │
│   ├── core/                    # Core infrastructure
│   │   ├── storage.coffee
│   │   └── typed-storage.coffee
│   │
│   ├── api/                    # AI API layer
│   │   ├── index.coffee
│   │   ├── base.coffee
│   │   ├── zhipu.coffee
│   │   ├── openrouter.coffee
│   │   └── tools.coffee
│   │
│   ├── ipc/                    # IPC handlers
│   │   ├── index.coffee
│   │   ├── session.coffee
│   │   ├── bot.coffee
│   │   ├── settings.coffee
│   │   ├── license.coffee
│   │   ├── system.coffee
│   │   ├── openclaw.coffee
│   │   ├── feishu.coffee
│   │   └── backup.coffee
│   │
│   ├── skills/                 # Skill handlers
│   │   ├── index.coffee
│   │   ├── fs.coffee
│   │   ├── code.coffee
│   │   └── git.coffee
│   │
│   └── models/                # Domain classes
│       ├── model.coffee
│       ├── bot.coffee
│       ├── session.coffee
│       ├── settings.coffee
│       └── license.coffee
│
├── test/                      # Tests
├── .github/workflows/         # CI
├── ARCHITECTURE.md
└── package.json
```
