# OpenClaw Collaboration Plan

## Goal
Enable OpenClaw Agent to directly participate in CoffeeClaw development through the app's chat interface.

## Current Status (2026-03-09)

### ✅ Working
- OpenRouter API key configured and working
- OpenClaw Agent responds in CoffeeClaw app
- Agent can read files in coffeeclaw project
- Agent can write files to coffeeclaw project
- Tool calling works (read, write, edit, exec)

### Test Results
```
$ openclaw agent --message "Read /Users/jk/gits/hub/tools_ai/coffeeclaw/README.md"
→ Successfully read and summarized the project

$ openclaw agent --message "Create file at .../OPENCLAW_TEST.md"
→ File created successfully
```

## Phase 1: Basic File Operations (Current)

### Step 1.1: Modify an Existing MD File
**Task**: Ask OpenClaw to update `CONVERSATION_SUMMARY.md` with current status.

**Prompt to use in app**:
```
请更新 /Users/jk/gits/hub/tools_ai/coffeeclaw/CONVERSATION_SUMMARY.md 文件，
在"当前问题"部分添加以下内容：

## 已解决问题 (2026-03-09)

### OpenRouter 配置
- ✅ OpenRouter API Key 已更新并验证
- ✅ 免费模型支持工具调用
- ✅ OpenClaw Agent 可以读写项目文件

### 响应解析修复
- ✅ 修复了响应解析问题（payloads 在根级别而非嵌套）
```

### Step 1.2: Verify Changes
After OpenClaw makes changes:
1. Check the file content
2. Commit the changes
3. Push to git

## Phase 2: Code Modifications

### Step 2.1: Simple Code Change
Ask OpenClaw to:
- Add a new function
- Fix a bug
- Add a feature

### Step 2.2: Test & Commit
- Run `npm run compile`
- Test the app
- Commit changes

## Phase 3: Complex Development

### Step 3.1: Feature Development
- Design a feature
- Implement it
- Test it
- Document it

## How to Use

### In CoffeeClaw App
1. Select "OpenClaw Agent" from bot dropdown
2. Give clear instructions with full file paths
3. Ask OpenClaw to read files first if needed
4. Request specific changes

### Example Prompts

**Read a file**:
```
请读取 /Users/jk/gits/hub/tools_ai/coffeeclaw/src/main.coffee 文件，
告诉我 MODELS 配置在哪里
```

**Modify a file**:
```
请编辑 /Users/jk/gits/hub/tools_ai/coffeeclaw/README.md，
在 Features 部分添加一条：支持 OpenClaw Agent 直接参与开发
```

**Create a file**:
```
请在 /Users/jk/gits/hub/tools_ai/coffeeclaw/documents/ 目录下
创建一个新文件 COLLABORATION.md，内容是关于如何与 OpenClaw 协作开发
```

## Key Paths

| Path | Purpose |
|------|---------|
| `/Users/jk/gits/hub/tools_ai/coffeeclaw/` | Project root |
| `/Users/jk/gits/hub/tools_ai/coffeeclaw/src/main.coffee` | Main process |
| `/Users/jk/gits/hub/tools_ai/coffeeclaw/index.html` | UI |
| `/Users/jk/gits/hub/tools_ai/coffeeclaw/.secrete/` | Settings |
| `~/.openclaw/workspace/` | OpenClaw workspace |

## Notes

- Always use full absolute paths
- OpenClaw can read, write, edit files
- OpenClaw can execute shell commands
- Changes are immediate (no confirmation)
- Remember to commit changes to git
