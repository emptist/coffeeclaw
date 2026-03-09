# CoffeeClaw 开发总结 (2026-03-09)

## 项目概述
CoffeeClaw 是一个基于 Electron 的桌面应用，集成了 OpenClaw Agent 作为 AI 助手。

## 已完成功能

### 1. OpenClaw Agent 集成
- 作为 Bot 模板集成到 CoffeeClaw
- 模型选择下拉框中添加了 "OpenClaw Agent (Direct)" 选项
- 使用 `openclaw agent --local --session-id` 命令调用

### 2. 会话管理
- 普通会话存储在 `.secrete/sessions.json`
- OpenClaw Agent 会话单独存储在 `.secrete/agent-sessions.json`
- 会话文件位于 `~/.openclaw/agents/main/sessions/`

### 3. 多 Provider 支持
- Zhipu GLM (glm-4-flash, glm-4-plus, glm-4-air)
- OpenRouter (openrouter/auto, gemini-2.0-flash, llama-3.3-70b, deepseek-chat) **[新增]**
- OpenAI (gpt-4o-mini, gpt-4o, gpt-4-turbo)
- DeepSeek (deepseek-chat, deepseek-coder)

### 4. API Key 管理
- 通过 UI 界面管理各 Provider 的 API Key
- 设置存储在 `.secrete/settings.json`
- OpenRouter API Key 已有: `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`

## 当前问题

### 工具调用限制
| 模型 | 工具调用支持 | 状态 |
|------|-------------|------|
| GLM-4-Flash | ❌ 不支持 | 可用但无法调用工具 |
| GLM-4-Plus | ✅ 支持 | 余额不足 |
| GLM-4-Air | ✅ 支持 | 余额不足 |
| OpenRouter 免费模型 | ✅ 支持 | 需配置 API Key |

### OpenClaw Agent 行为
- GLM-4-Flash 返回 `NO_REPLY` 或普通文本，不调用工具
- 需要支持工具调用的模型才能让 OpenClaw Agent 执行文件操作

## 下一步任务

1. **配置 OpenRouter API Key**
   - 在 CoffeeClaw 设置界面添加 OpenRouter 的 API Key
   - Key 已存储在 `.secrete/AI.md`
   - 测试工具调用功能

2. **测试 OpenClaw Agent 文件写入**
   ```bash
   openclaw agent --local --session-id "test" --message "Use the write tool to create a file..."
   ```

3. **验证 OpenRouter 模型工具调用**
   - 使用 `openrouter/auto` 或 `google/gemini-2.0-flash-001`
   - 这些免费模型支持 Function Calling

## 关键文件

| 文件 | 用途 |
|------|------|
| `src/main.coffee` | 主进程，包含 MODELS 配置和 API 调用逻辑 |
| `index.html` | 渲染进程，UI 界面 |
| `src/preload.coffee` | 预加载脚本，暴露 API |
| `.secrete/settings.json` | 用户设置和 API Keys |
| `.secrete/agent-sessions.json` | OpenClaw Agent 会话 |
| `.secrete/bots.json` | Bot 配置 |
| `~/.openclaw/openclaw.json` | OpenClaw 配置 |

## OpenClaw 配置要点

```json
// ~/.openclaw/openclaw.json
{
  "models": {
    "providers": {
      "glm": {
        "baseUrl": "https://open.bigmodel.cn/api/paas/v4",
        "apiKey": "...",
        "models": [
          { "id": "GLM-4-Flash" },
          { "id": "GLM-4-Plus" },
          { "id": "GLM-4-Air" }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "glm/GLM-4-Flash"
      }
    }
  }
}
```

## Git 提交历史
- `2cb67cb` - Add OpenRouter provider support for tool calling models
- 之前的提交包含 OpenClaw Agent 集成、Bot 模板系统、会话管理等

## 注意事项
- GLM-4-Flash 不支持工具调用，需要使用 GLM-4-Plus/Air 或 OpenRouter 模型
- OpenRouter 免费额度：每天 50 次调用
- 工具调用需要模型支持 Function Calling

## 已解决问题 (2026-03-09 更新)

### OpenRouter 配置
- ✅ OpenRouter API Key 已更新并验证可用
- ✅ 免费模型 (openrouter/auto) 支持工具调用
- ✅ OpenClaw Agent 可以读写 coffeeclaw 项目文件

### 响应解析修复
- ✅ 修复了响应解析问题（payloads 在根级别而非嵌套在 result 中）
- ✅ 移除了无用的 save-api-key 死代码

### Provider 同步
- ✅ 实现了 CoffeeClaw 与 OpenClaw 配置的自动同步
- ✅ 修复了配置路径：使用 agents.defaults.model.primary
