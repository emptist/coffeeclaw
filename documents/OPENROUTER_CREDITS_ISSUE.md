# OpenRouter Credits Issue

## Problem

OpenClaw agent failed with error:
```
402 This request requires more credits, or fewer max_tokens.
You requested up to 4096 tokens, but can only afford 1045.
To increase, visit https://openrouter.ai/settings/credits and upgrade to a paid account
```

## Root Cause

OpenRouter free tier has been exhausted. The account has:
- **Available credits:** 1045 tokens
- **Requested tokens:** 4096 tokens
- **Deficit:** 3051 tokens

## Impact

- ❌ OpenClaw agent cannot execute tasks
- ❌ Cannot use OpenRouter models for agent execution
- ✅ Zhipu (GLM-4-Flash) still works for regular conversations
- ✅ Can still use agent for simple tasks (under 1045 tokens)

## Solutions

### Option 1: Get More OpenRouter Credits (Recommended)

**Steps:**
1. Visit https://openrouter.ai/settings/credits
2. Upgrade to paid account OR
3. Wait for free tier reset (if applicable)

**Benefits:**
- ✅ Full agent capabilities restored
- ✅ Access to all OpenRouter models
- ✅ Higher token limits

### Option 2: Use Zhipu for Agent Execution (Temporary)

**Modify OpenClaw config:**
```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "glm/GLM-4-Flash"
      }
    }
  }
}
```

**Limitations:**
- ⚠️ GLM-4-Flash lacks function calling capabilities
- ⚠️ Agent cannot execute tools (file operations, etc.)
- ⚠️ Only suitable for simple conversations

### Option 3: Reduce Token Usage

**Modify OpenClaw config:**
```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "openrouter/auto",
        "maxTokens": 1000
      }
    }
  }
}
```

**Limitations:**
- ⚠️ Very limited context
- ⚠️ May truncate responses
- ⚠️ Not suitable for complex tasks

### Option 4: Create New OpenRouter Account

**Steps:**
1. Create new OpenRouter account
2. Get new API key
3. Update CoffeeClaw settings with new key

**Benefits:**
- ✅ Fresh free tier credits
- ✅ Full agent capabilities

**Drawbacks:**
- ⚠️ Against terms of service (possibly)
- ⚠️ Temporary solution

## Recommended Action

**Best approach:** Upgrade OpenRouter account or wait for credit reset

**Why:**
- OpenRouter provides best agent execution capabilities
- Free tier is generous but limited
- Paid plans are affordable and reliable

## Current Status

- **Primary model:** `openrouter/auto` (configured but out of credits)
- **Fallback model:** `glm/GLM-4-Flash` (works but no function calling)
- **Agent status:** Limited to simple conversations

## Next Steps

1. Check OpenRouter credit status: https://openrouter.ai/settings/credits
2. Decide on solution (upgrade, wait, or create new account)
3. Update CoffeeClaw settings accordingly
4. Test agent execution

## Related

- [documents/PROVIDER_CAPABILITIES.md](file:///Users/jk/gits/hub/tools_ai/coffeeclaw/documents/PROVIDER_CAPABILITIES.md) - Provider comparison
- [documents/PROVIDER_SELECTION_REFACTORING.md](file:///Users/jk/gits/hub/tools_ai/coffeeclaw/documents/PROVIDER_SELECTION_REFACTORING.md) - Provider selection logic
