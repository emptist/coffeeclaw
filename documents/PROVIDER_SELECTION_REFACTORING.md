# Provider Selection Refactoring Plan

## Overview

Refactor the provider/model selection logic to make OpenClaw config the single source of truth for model configuration.

## Current Issues

1. `activeProvider` in CoffeeClaw and `primary model` in OpenClaw are coupled incorrectly
2. Hardcoded provider strings scattered throughout codebase
3. Sync logic is confusing (two-way sync with unclear ownership)

## Architecture Design

### Single Source of Truth

```
┌─────────────────────────────────────────────────────────────────┐
│           OpenClaw Config (Single Source of Truth)              │
│                                                                  │
│  models.providers: { glm, openrouter, openai }                  │
│  agents.defaults.model.primary: "openrouter/auto"               │
│  gateway.auth.token: "xxx"                                      │
│                                                                  │
│  Methods:                                                        │
│    - determinePrimaryModel() → "openrouter/auto"                │
│    - hasProvider(name) → true/false                             │
│    - setProvider(name, apiKey)                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Use Cases

| Use Case | Path | Model Selection |
|----------|------|-----------------|
| OpenClaw CLI | OpenClaw config `primary` | `determinePrimaryModel()` |
| CoffeeClaw GUI | CoffeeClaw bot system | `selectProvider(bot)` |
| Feishu (via CoffeeClaw) | CoffeeClaw bot system | `selectProvider(bot)` |

### Key Principle

- **OpenClaw config `primary`** = Only for standalone CLI (always agent, needs function calling)
- **CoffeeClaw runtime** = Uses `selectProvider(bot)` based on bot type

### Model Selection Logic

| Bot Type | Provider | Reason |
|----------|----------|--------|
| Agent | OpenRouter → OpenAI → Zhipu | Needs function calling |
| Normal | Zhipu | Free tier |

## Implementation Steps

### Step 1: Add constants to Model classes

**File**: `src/model.coffee`

```coffee
class ZhipuModel extends Model
  @PROVIDER_NAME: 'zhipu'
  @OPENCLAW_PREFIX: 'glm'
  @DEFAULT_MODEL: 'GLM-4-Flash'

class OpenRouterModel extends Model
  @PROVIDER_NAME: 'openrouter'
  @OPENCLAW_PREFIX: 'openrouter'
  @DEFAULT_MODEL: 'auto'

class OpenAIModel extends Model
  @PROVIDER_NAME: 'openai'
  @OPENCLAW_PREFIX: 'openai'
  @DEFAULT_MODEL: 'gpt-4o'
```

### Step 2: Add `determinePrimaryModel()` to OpenClawConfig

**File**: `src/openclaw-config.coffee`

```coffee
{ Model, ZhipuModel, OpenRouterModel, OpenAIModel } = require './model'

class OpenClawConfig
  hasProvider: (providerId) ->
    openClawName = @getOpenClawName(providerId)
    @data.models?.providers?[openClawName]?.apiKey?
  
  getOpenClawName: (providerId) ->
    switch providerId
      when Model.PROVIDER_ZHIPU then ZhipuModel.OPENCLAW_PREFIX
      when Model.PROVIDER_OPENROUTER then OpenRouterModel.OPENCLAW_PREFIX
      when Model.PROVIDER_OPENAI then OpenAIModel.OPENCLAW_PREFIX
      else providerId
  
  determinePrimaryModel: ->
    if @hasProvider(Model.PROVIDER_OPENROUTER)
      "#{OpenRouterModel.OPENCLAW_PREFIX}/#{OpenRouterModel.DEFAULT_MODEL}"
    else if @hasProvider(Model.PROVIDER_OPENAI)
      "#{OpenAIModel.OPENCLAW_PREFIX}/#{OpenAIModel.DEFAULT_MODEL}"
    else
      "#{ZhipuModel.OPENCLAW_PREFIX}/#{ZhipuModel.DEFAULT_MODEL}"
```

### Step 3: Update `syncFromSettings()` to use `determinePrimaryModel()`

**File**: `src/openclaw-config.coffee`

```coffee
syncFromSettings: (settings) ->
  # ... existing provider sync logic ...
  
  # Set primary model based on available providers
  primaryModel = @determinePrimaryModel()
  @setPrimaryModelRaw(primaryModel)
  
  @save()
```

### Step 4: Update OpenClawManager.syncProviders()

**File**: `src/openclaw-manager.coffee`

Replace hardcoded logic with OpenClawConfig methods.

### Step 5: Keep `selectProvider(bot)` in OpenClawManager

This is for CoffeeClaw runtime selection (GUI + Feishu).

```coffee
selectProvider: (settings, bot) ->
  isAgent = bot?.isAgent?() or bot?.model?.rawId?() == 'openclaw-agent'
  
  if isAgent
    if settings.providers?.openrouter?.apiKey
      return Model.PROVIDER_OPENROUTER
    else if settings.providers?.openai?.apiKey
      return Model.PROVIDER_OPENAI
    else
      return Model.PROVIDER_ZHIPU
  else
    return Model.PROVIDER_ZHIPU
```

### Step 6: Remove hardcoded strings

Replace all hardcoded 'zhipu', 'openrouter', 'openai' with Model class constants.

## Files to Modify

1. `src/model.coffee` - Add constants
2. `src/openclaw-config.coffee` - Add determinePrimaryModel(), hasProvider()
3. `src/openclaw-manager.coffee` - Update syncProviders(), selectProvider()
4. `src/settings.coffee` - Use Model constants (if needed)
5. `src/core/typed-storage.coffee` - Update sync logic (if needed)

## Testing Plan

1. Test OpenClaw CLI with `openclaw agent` command
2. Test CoffeeClaw GUI with Agent bot
3. Test CoffeeClaw GUI with Normal bot
4. Test Feishu integration
5. Test sync after adding/removing API keys

## Status

- [x] Step 1: Add constants to Model classes
- [x] Step 2: Add determinePrimaryModel() to OpenClawConfig
- [x] Step 3: Update syncFromSettings()
- [x] Step 4: Update OpenClawManager.syncProviders()
- [x] Step 5: Keep selectProvider(bot) in OpenClawManager
- [x] Step 6: Remove hardcoded strings
- [ ] Testing

---

## Alternative Approach: CoffeeClaw as Main Role

### Concept

What if we take CoffeeClaw as the single source of truth instead of OpenClaw?

```
┌─────────────────────────────────────────────────────────────────┐
│           CoffeeClaw Settings (Single Source of Truth)          │
│                                                                  │
│  providers: { zhipu, openrouter, openai }                       │
│  activeProvider: "openrouter"                                   │
│  token: "xxx"                                                   │
│                                                                  │
│  Methods:                                                        │
│    - determinePrimaryModel() → "openrouter/auto"                │
│    - hasProvider(name) → true/false                             │
│    - setProvider(name, apiKey)                                   │
│                                                                  │
│  CoffeeClaw-specific:                                            │
│  - feishu, userEmail, activeBotId, sessions                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ One-way sync (CoffeeClaw → OpenClaw)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    OpenClaw Config (Derived)                     │
│                                                                  │
│  models.providers: (synced from CoffeeClaw)                     │
│  agents.defaults.model.primary: (synced from CoffeeClaw)        │
│  gateway.auth.token: (synced from CoffeeClaw)                   │
└─────────────────────────────────────────────────────────────────┘
```

### Analysis

#### Pros

1. **User-centric**: User interacts with CoffeeClaw GUI, settings should be there
2. **Simpler mental model**: One place to manage all settings
3. **CoffeeClaw-specific settings**: Already in CoffeeClaw (feishu, email, bots, sessions)
4. **GUI-first**: All user actions happen in CoffeeClaw

#### Cons

1. **OpenClaw CLI independence**: OpenClaw can run standalone without CoffeeClaw
2. **Config file location**: OpenClaw config is in `~/.openclaw/`, CoffeeClaw in project
3. **Direct OpenClaw usage**: Users might edit OpenClaw config directly
4. **Two systems**: OpenClaw has its own configuration philosophy

### Key Questions

1. **Who is the primary user?**
   - If user only uses CoffeeClaw → CoffeeClaw as source of truth
   - If user also uses OpenClaw CLI directly → OpenClaw as source of truth

2. **What happens when user edits OpenClaw config directly?**
   - CoffeeClaw as source: Changes will be overwritten on next sync
   - OpenClaw as source: CoffeeClaw reads and respects changes

3. **Where should `determinePrimaryModel()` live?**
   - CoffeeClaw as source: In Settings class
   - OpenClaw as source: In OpenClawConfig class

### Comparison Table

| Aspect | OpenClaw as Source | CoffeeClaw as Source |
|--------|-------------------|---------------------|
| User edits OpenClaw directly | Respected | Overwritten |
| OpenClaw CLI standalone | Works naturally | Needs sync first |
| CoffeeClaw GUI | Needs sync | Direct access |
| Single source location | `~/.openclaw/openclaw.json` | `.secrete/coffeeclaw-data.json` |
| Feishu/Email settings | Separate | Integrated |
| Mental model | Two systems | One system |

### Recommendation

**Stick with OpenClaw as source of truth** because:

1. **OpenClaw is the execution engine** - CoffeeClaw is just a GUI wrapper
2. **OpenClaw can run independently** - Users might use CLI directly
3. **Config file location** - OpenClaw config is in standard location (`~/.openclaw/`)
4. **Consistency** - OpenClaw CLI and CoffeeClaw should see the same configuration

However, CoffeeClaw should:
- Read from OpenClaw config on startup
- Write to OpenClaw config when user changes settings
- Have its own settings for GUI-specific things (feishu, email, bots, sessions)
