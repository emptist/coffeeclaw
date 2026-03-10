# Provider Capabilities Guide

## Overview

Different AI providers and models have different capabilities. This guide documents the critical knowledge for choosing the right provider for your use case.

## Provider Comparison

| Provider | Free Tier | Function Calling | Agent Capable | Rate Limit |
|----------|-----------|------------------|---------------|------------|
| **Zhipu GLM-4-Flash** | ✅ Completely FREE | ✅ Yes | ❌ No | No limits |
| **OpenRouter** | ⚠️ 50 req/day | ✅ Yes | ✅ Yes | 20 RPM |
| **OpenAI** | ❌ Paid only | ✅ Yes | ✅ Yes | Pay per use |

## OpenRouter Free Tier Details

- **Free tier limit**: 50 requests per day (resets daily)
- **Rate limit**: 20 requests per minute
- **After hitting limit**: Returns 429 Rate Limit error, blocked until next day
- **Balance >= $10**: Upgraded to 1000 requests per day

## Model Capabilities

### What is "Agent Capable"?

OpenClaw agent execution requires more than basic function calling. A model is "agent capable" if it can:

1. **Multi-step reasoning** - Plan and execute complex task sequences
2. **Tool orchestration** - Understand when and how to call multiple tools
3. **Error handling** - Retry, recover, and adapt when operations fail
4. **Task decomposition** - Break down complex requests into executable steps

### Why GLM-4-Flash is NOT Agent Capable

GLM-4-Flash is a "Flash" model optimized for **speed**, not complex reasoning:

| Capability | GLM-4-Flash | Agent-Capable Models |
|------------|-------------|---------------------|
| Basic function calling | ✅ Yes | ✅ Yes |
| Multi-step reasoning | ❌ Weak | ✅ Strong |
| Tool orchestration | ❌ Not suitable | ✅ Suitable |
| Error recovery | ❌ Limited | ✅ Good |
| Task planning | ❌ Basic | ✅ Advanced |

**Result**: GLM-4-Flash works fine for simple chat bots with basic tool calls, but will fail when asked to execute complex OpenClaw agent tasks like file operations, command execution, or multi-step workflows.

## Provider Strategy

### Use Case: Normal Bots (Chat)

**Recommended**: Zhipu GLM-4-Flash

- Completely free
- Fast response (72 tokens/s)
- 128K context
- Basic function calling works
- Good for: chatbots, Q&A, simple tool calls

### Use Case: OpenClaw Agent (Execution)

**Recommended**: OpenRouter

- Free tier: 50 requests/day
- Access to agent-capable models:
  - `openrouter/auto` - Auto-selects best model
  - `google/gemini-2.0-flash-001` - Strong reasoning
  - `meta-llama/llama-3.3-70b-instruct` - Good for code
- Required for: file operations, command execution, multi-step workflows

### Use Case: Production/Heavy Usage

**Recommended**: OpenAI (paid)

- No rate limits (pay per use)
- GPT-4o, GPT-4o-mini are agent capable
- Best reliability for production

## Configuration

### MODELS Config Structure

```coffeescript
MODELS =
  zhipu:
    name: 'Zhipu GLM'
    models: [
      { 
        id: 'glm-4-flash', 
        name: 'GLM-4-Flash (Free)', 
        free: true, 
        functionCalling: true, 
        agentCapable: false  # Critical: NOT suitable for OpenClaw agent
      }
    ]
  openrouter:
    name: 'OpenRouter'
    models: [
      { 
        id: 'openrouter/auto', 
        name: 'Auto (Free: 50 req/day)', 
        free: true, 
        freeLimit: '50/day',
        agentCapable: true  # Suitable for OpenClaw agent
      }
    ]
```

### Key Flags

- `free: true` - Model has free tier
- `freeLimit: '50/day'` - Free tier limitation
- `functionCalling: true` - Supports basic function calling
- `agentCapable: true` - Suitable for OpenClaw agent execution

## OpenClaw Configuration

OpenClaw requires the model to be configured in `~/.openclaw/openclaw.json`:

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "openrouter/auto"
      }
    }
  }
}
```

**Important**: Never set `primary` to a GLM model for agent execution. Use OpenRouter or OpenAI models instead.

## Troubleshooting

### Agent fails to execute tasks

**Symptom**: OpenClaw agent cannot write files, execute commands, or complete multi-step tasks.

**Cause**: Using GLM-4-Flash or other non-agent-capable model.

**Solution**: Switch to OpenRouter or OpenAI model in OpenClaw config.

### 429 Rate Limit errors

**Symptom**: OpenRouter API returns 429 error.

**Cause**: Exceeded 50 requests/day free tier limit.

**Solution**: 
1. Wait for daily reset
2. Add $10+ balance for 1000 req/day
3. Switch to paid provider (OpenAI)

### Function calling works but agent doesn't

**Symptom**: Basic function calling works, but OpenClaw agent fails.

**Cause**: Function calling ≠ Agent capability. Agent requires multi-step reasoning.

**Solution**: Use agent-capable model (OpenRouter, OpenAI).

## References

- [Zhipu GLM-4-Flash Documentation](https://open.bigmodel.cn)
- [OpenRouter Pricing](https://openrouter.ai/docs/limits)
- [OpenClaw Documentation](https://openclaw.ai)
