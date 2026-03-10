# CoffeeClaw Class Architecture

## Overview

This document describes the class hierarchy introduced to solve the model ID format confusion and improve code organization.

## Class List

### 1. Model Classes (`src/model.coffee`)

Base class and subclasses for different AI providers.

#### Model (Base)
```coffee
class Model
  @PROVIDER_NAME: null      # Class property - provider identifier
  @OPENCLAW_NAME: null      # Class property - OpenClaw provider name
  
  constructor: (@id) ->
  rawId: -> @id
  fullId: -> "#{@provider}/#{@id}"
  apiId: -> throw new Error("Subclass must implement")
  openClawId: -> throw new Error("Subclass must implement")
```

#### ZhipuModel
- `apiId()`: `glm-4-flash` (no prefix for Zhipu API)
- `openClawId()`: `glm/glm-4-flash` (with glm/ prefix)

#### DeepSeekModel
- `apiId()`: `deepseek-chat`
- `openClawId()`: `deepseek/deepseek-chat`

#### OpenAIModel
- `apiId()`: `gpt-4o`
- `openClawId()`: `openai/gpt-4o`

#### OpenRouterModel
- `apiId()`: `openrouter/google/gemini-2.0-flash` (full path)
- `openClawId()`: `openrouter/google/gemini-2.0-flash`

### 2. Bot Class (`src/bot.coffee`)

Manages AI assistants.

```coffee
class Bot
  @DEFAULT_SKILLS = ['*']
  @MAX_NAME_LENGTH = 50
  
  constructor: (@id, @name, @description, @model, @systemPrompt, @skills) ->
  isAgent: -> @model?.rawId() == 'openclaw-agent'
  getDisplayName: -> "#{@name} (#{@model.fullId()})"
```

### 3. Session Classes (`src/session.coffee`)

Manages chat conversations.

#### Session
```coffee
class Session
  @MAX_MESSAGES = 1000
  
  constructor: (@id, @botId, @title) ->
  addMessage: (role, content, metadata) ->
  addUserMessage: (content) ->
  addAssistantMessage: (content) ->
  getHistoryForAPI: (limit) ->
```

#### SessionManager
```coffee
class SessionManager
  addSession: (session) ->
  getSession: (id) ->
  setActiveSession: (id) ->
  getAllSessions: () ->
```

### 4. Settings Class (`src/settings.coffee`)

Manages application configuration.

```coffee
class Settings
  @DEFAULT_PROVIDER = 'zhipu'
  @SUPPORTED_PROVIDERS = ['zhipu', 'deepseek', 'openai', 'openrouter']
  
  constructor: ->
  setProvider: (id, apiKey, model) ->
  setActiveProvider: (id) ->
  getActiveModel: () ->
  setFeishu: (config) ->
  @fromLegacy: (data) ->  # Migration from old format
```

### 5. FeishuConfig Class (`src/feishu-config.coffee`)

Manages Feishu (Lark) integration.

```coffee
class FeishuConfig
  @DEFAULT_BOT_NAME = 'CoffeeClaw'
  @SUPPORTED_POLICIES = ['open', 'pairing', 'disabled']
  
  constructor: (options) ->
  isValid: () ->
  canRespondToDM: () ->
  needsPairingForDM: () ->
  validate: () ->
```

### 6. OpenClawConfig Class (`src/openclaw-config.coffee`)

Manages OpenClaw agent configuration.

```coffee
class OpenClawConfig
  @CONFIG_FILE: '~/.openclaw/openclaw.json'
  @PROVIDER_NAME_MAP:
    zhipu: 'glm'
    openrouter: 'openrouter'
    deepseek: 'deepseek'
    openai: 'openai'
  
  constructor: ->
  load: () ->
  save: () ->
  setProvider: (providerId, apiKey, baseUrl) ->
  setPrimaryModel: (providerId, modelId) ->
  setToken: (token) ->
  syncFromSettings: (settings) ->
  backup: () ->
```

### 7. License Class (`src/license.coffee`)

Manages user license.

```coffee
class License
  @STATUS_ACTIVE = 'active'
  @STATUS_EXPIRED = 'expired'
  @GRACE_PERIOD_DAYS = 7
  
  constructor: (@key, @userId) ->
  isValid: () ->
  isExpired: () ->
  activate: (features, quota) ->
  useQuota: (amount) ->
  hasFeature: (feature) ->
```

### 8. Identity Class (`src/identity.coffee`)

Manages machine identity.

```coffee
class Identity
  constructor: ->
  generateMachineId: () ->
  verify: () ->
  getShortId: () ->
```

### 9. BackupManager Class (`src/backup-manager.coffee`)

Manages data backup and restore.

```coffee
class BackupManager
  @DEFAULT_BACKUP_DIR: '~/.coffeeclaw/backups'
  @MAX_BACKUPS = 20
  
  constructor: (backupDir) ->
  createBackup: (data) ->
  listBackups: () ->
  loadBackup: (filename) ->
  restoreBackup: (filename, handler) ->
  cleanupOldBackups: (keep) ->
```

### 10. AgentModel Classes (`src/agent-model.coffee`)

Manages AI agent configurations.

#### AgentModel
```coffee
class AgentModel
  @DEFAULT_MAX_TOKENS = 4096
  @SUPPORTED_CAPABILITIES = ['chat', 'code', 'search', 'image', 'voice']
  
  constructor: (@id, @name, @description, @model) ->
  addCapability: (capability) ->
  hasCapability: (capability) ->
  canHandle: (taskType) ->
  getApiConfig: () ->
```

#### AgentModelManager
```coffee
class AgentModelManager
  addAgent: (agent) ->
  getAgent: (id) ->
  getDefaultAgent: () ->
  findByCapability: (capability) ->
```

## Design Principles

### 1. Class Properties vs Instance Properties

**Class Properties (Static)**: Defined with `@` prefix, shared across all instances
```coffee
class Model
  @PROVIDER_NAME = 'zhipu'  # Class property
  
  constructor: (@id) ->      # Instance property
```

**Instance Properties**: Defined in constructor, unique to each instance

### 2. Serialization

All classes implement:
- `toJSON()`: Serialize to plain object (only instance properties)
- `fromJSON(data)`: Deserialize and recreate class instance
- `fromLegacy(data)`: Migrate from old format

### 3. Inheritance

Single-level inheritance only:
```
Model (base)
├── ZhipuModel
├── DeepSeekModel
├── OpenAIModel
└── OpenRouterModel
```

No deep inheritance hierarchies.

### 4. Provider-Specific Logic

Each provider subclass implements its own ID formatting:
```coffee
class ZhipuModel extends Model
  apiId: -> @id                    # No prefix
  openClawId: -> "glm/#{@id}"     # With glm/ prefix

class OpenRouterModel extends Model
  apiId: -> "#{@provider}/#{@id}" # Full path
```

## Migration Strategy

### From Old Format

Use `fromLegacy()` methods:
```coffee
# Old format (plain object)
oldSettings = JSON.parse(fs.readFileSync('settings.json'))

# Convert to class
settings = Settings.fromLegacy(oldSettings)
```

### To New Format

Use `toJSON()` for storage:
```coffee
# Save class instance
fs.writeFileSync('settings.json', JSON.stringify(settings.toJSON()))
```

## Benefits

1. **Type Safety**: Clear class hierarchy prevents ID format errors
2. **Encapsulation**: Provider-specific logic in respective classes
3. **Testability**: Each class can be unit tested independently
4. **Maintainability**: Changes localized to specific classes
5. **Serialization**: Consistent save/restore across all data types
