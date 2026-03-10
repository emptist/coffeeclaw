# 我是怎样跟龙虾协作开发的

> 记录一次与 OpenClaw Agent（代号"龙虾"）协作开发 CoffeeClaw 的完整经历

## 缘起

CoffeeClaw 是一个基于 Electron 的桌面 AI 助手应用，原本只是想做一个简单的聊天界面。但随着需求增长，需要集成更多功能：GitHub 操作、飞书集成、文件管理、网页搜索等。如果全部自己开发，工作量巨大。

这时想到了 OpenClaw Agent——一个功能强大的 AI 代理框架，它已经具备了：
- 文件读写编辑能力
- Shell 命令执行
- GitHub CLI 集成
- 飞书消息发送
- 网页抓取和截图
- 定时任务管理

如果能把这些能力"借"到 CoffeeClaw 中，岂不是事半功倍？

于是，一场与"龙虾"（OpenClaw Agent 的昵称）的协作之旅开始了。

---

## 一、配置细节

### 1.1 OpenClaw 配置文件

OpenClaw 的配置位于 `~/.openclaw/openclaw.json`：

```json
{
  "version": "1.0.0",
  "agents": {
    "defaults": {
      "model": {
        "primary": "openrouter/auto"
      }
    }
  },
  "providers": {
    "glm": {
      "apiKey": "your-zhipu-api-key"
    },
    "openrouter": {
      "apiKey": "sk-or-v1-your-openrouter-key"
    }
  },
  "channels": {
    "feishu": {
      "enabled": true,
      "appId": "cli_xxx",
      "appSecret": "xxx"
    }
  }
}
```

### 1.2 CoffeeClaw 配置同步

CoffeeClaw 有自己的配置文件 `.secrete/settings.json`，需要与 OpenClaw 同步：

```javascript
// 同步逻辑 (main.coffee)
syncProvidersToOpenClaw = (providers, activeProvider) ->
  openclawConfig = JSON.parse fs.readFileSync(openclawPath, 'utf-8')
  
  # 映射 CoffeeClaw 名称到 OpenClaw 名称
  PROVIDER_NAME_MAP =
    'zhipu': 'glm'
    'openrouter': 'openrouter'
    'openai': 'openai'
    'deepseek': 'deepseek'
  
  # 同步 providers
  for providerId, config of providers
    ocName = PROVIDER_NAME_MAP[providerId] or providerId
    openclawConfig.providers[ocName] =
      apiKey: config.apiKey
  
  # 设置默认模型
  openclawConfig.agents.defaults.model.primary = "#{activeProvider}/auto"
  
  fs.writeFileSync openclawPath, JSON.stringify(openclawConfig, null, 2)
```

### 1.3 关键配置路径

踩坑记录：OpenClaw 的默认模型配置路径是 `agents.defaults.model.primary`，不是 `defaults.model.primary`！

```javascript
// ❌ 错误写法
config.defaults.model.primary = "openrouter/auto"

// ✅ 正确写法
config.agents.defaults.model.primary = "openrouter/auto"
```

---

## 二、Setup 过程

### 2.1 安装 OpenClaw

```bash
# 全局安装
npm install -g openclaw

# 初始化配置
openclaw init

# 验证安装
openclaw --version
```

### 2.2 配置 API Key

我们选择了 OpenRouter 作为主要提供商，因为它提供：
- 100+ 模型选择（Claude, GPT-4, Gemini 等）
- 免费额度
- 统一的 API 接口

```bash
# 获取 API Key
# 访问 https://openrouter.ai/keys

# 配置到 OpenClaw
openclaw config set providers.openrouter.apiKey "sk-or-v1-xxx"
```

### 2.3 验证配置

```bash
# 运行诊断
openclaw doctor

# 测试调用
openclaw agent --local --message "Hello, are you working?" --json
```

### 2.4 飞书集成配置

```bash
# 启用飞书通道
openclaw config set channels.feishu.enabled true

# 配置应用凭证
openclaw config set channels.feishu.appId "cli_xxx"
openclaw config set channels.feishu.appSecret "xxx"
```

---

## 三、Prompt 实例

### 3.1 基础对话

```bash
openclaw agent --local \
  --session-id "chat-001" \
  --message "你好，请介绍一下你自己" \
  --json
```

### 3.2 文件操作

```bash
# 读取文件
openclaw agent --local \
  --message "Read file: /path/to/file.txt" \
  --json

# 写入文件
openclaw agent --local \
  --message "Write to file /tmp/test.txt: Hello World" \
  --json

# 编辑文件（查找替换）
openclaw agent --local \
  --message "Edit file /path/to/file: replace 'old' with 'new'" \
  --json
```

### 3.3 GitHub 操作

```bash
# 查看 Issues
openclaw agent --local \
  --message "List all open issues in emptist/coffeeclaw repo" \
  --json

# 创建 Issue
openclaw agent --local \
  --message "Create a GitHub issue in emptist/coffeeclaw with title 'Bug: JSON parsing fails' and body 'Details...'" \
  --json
```

### 3.4 飞书消息

```bash
openclaw agent --local \
  --message "Send feishu message: 今日进度更新 - 完成了工具面板集成" \
  --json
```

### 3.5 网页搜索

```bash
openclaw agent --local \
  --message "Search the web for: 伊朗战争历史" \
  --json
```

### 3.6 在代码中调用

```coffeescript
# CoffeeScript 调用示例
callOpenClawAgent = (sessionId, message) ->
  new Promise (resolve, reject) ->
    cmd = "openclaw agent --local --session-id \"#{sessionId}\" --message #{JSON.stringify(message)} --json 2>/dev/null"
    exec cmd, { maxBuffer: 1024 * 1024 * 10 }, (err, stdout, stderr) ->
      if err
        reject new Error(err.message)
        return
      
      # 提取 JSON（重要！）
      jsonMatch = stdout.match /\{[\s\S]*"payloads"[\s\S]*\}/
      if jsonMatch
        result = JSON.parse jsonMatch[0]
        text = result.payloads?[0]?.text or 'No response'
        resolve text
      else
        resolve stdout.trim()
```

---

## 四、挑战与解决

### 4.1 挑战一：JSON 解析失败

**问题描述**：
调用 OpenClaw Agent 时，返回的 `--json` 输出包含插件加载日志，导致 `JSON.parse()` 失败：

```
[plugins] feishu_doc: Registered feishu_doc...
[plugins] feishu_chat: Registered feishu_chat tool...
{"payloads": [...], "meta": {...}}
```

**解决方案**：
使用正则表达式提取 JSON 部分：

```javascript
function extractOpenClawResponse(stdout) {
  const jsonMatch = stdout.match(/\{[\s\S]*"payloads"[\s\S]*\}/);
  if (jsonMatch) {
    return JSON.parse(jsonMatch[0]);
  }
  return null;
}
```

**影响范围**：
- 主聊天窗口 (`main.coffee` 的 `callOpenClawAgent`)
- 所有工具面板的搜索、文件操作、飞书消息等功能

### 4.2 挑战二：配置不同步

**问题描述**：
用户在 CoffeeClaw UI 中配置了 OpenRouter，但 OpenClaw Agent 仍然使用 Zhipu。

**原因分析**：
- CoffeeClaw 保存配置到 `.secrete/settings.json`
- OpenClaw 读取配置从 `~/.openclaw/openclaw.json`
- 两者没有自动同步

**解决方案**：
实现双向同步机制：

1. **保存时同步**：在 `save-settings` IPC handler 中调用 `syncProvidersToOpenClaw()`
2. **启动时同步**：在 `ensureOpenClawConfig()` 中比较时间戳，自动同步更新的配置

```coffeescript
ensureOpenClawConfig = ->
  settingsStat = fs.statSync settingsFile
  openclawStat = fs.statSync openclawPath
  
  # 如果 CoffeeClaw 配置更新，同步到 OpenClaw
  if settingsStat.mtime > openclawStat.mtime
    syncProvidersToOpenClaw settings.providers, settings.activeProvider
```

### 4.3 挑战三：API Key 额度耗尽

**问题描述**：
OpenRouter 免费额度用完后，所有请求返回 "User not found" 错误。

**排查过程**：
```bash
# 测试 API Key
curl -H "Authorization: Bearer sk-or-v1-xxx" \
  https://openrouter.ai/api/v1/models

# 返回错误
{"error": "User not found"}
```

**解决方案**：
1. 检查 API Key 状态
2. 更新为新的有效 Key
3. 同步到 CoffeeClaw 和 OpenClaw 配置

### 4.4 挑战四：Electron prompt 不工作

**问题描述**：
在 Electron 中使用 `prompt()` 函数时，对话框不显示。

**原因**：
Electron 的安全限制，`prompt()` 和 `alert()` 行为不一致。

**解决方案**：
实现自定义模态对话框：

```html
<div class="custom-modal hidden" id="customModal">
  <div class="modal-content">
    <h3 id="modalTitle">标题</h3>
    <p id="modalMessage">提示信息</p>
    <textarea id="modalInput"></textarea>
    <div class="modal-buttons">
      <button onclick="closeModal(false)">取消</button>
      <button onclick="closeModal(true)" class="primary">确定</button>
    </div>
  </div>
</div>
```

```javascript
async function showCustomDialog(title, message, multiline = false) {
  return new Promise((resolve) => {
    const modal = document.getElementById('customModal');
    document.getElementById('modalTitle').textContent = title;
    document.getElementById('modalMessage').textContent = message;
    
    modal.classList.remove('hidden');
    modal.dataset.resolve = 'pending';
    
    window._modalResolve = resolve;
  });
}

function closeModal(confirm) {
  const modal = document.getElementById('customModal');
  const input = document.getElementById('modalInput');
  modal.classList.add('hidden');
  
  if (window._modalResolve) {
    window._modalResolve(confirm ? input.value : null);
  }
}
```

### 4.5 挑战五：UI 设计不够友好

**问题描述**：
原始工具面板只是简单的按钮列表，用户反馈"没有充分利用窗口空间"、"界面不够熟悉"。

**解决方案**：
采用用户熟悉的设计风格：

| 功能 | 设计参考 | 实现方式 |
|------|----------|----------|
| Web 搜索 | Google 首页 | 居中大搜索框 + "手气不错" |
| GitHub | GitHub Dashboard | 卡片网格布局 |
| 飞书 | 飞书工作台 | 图标卡片网格 |
| 文件管理 | Finder 风格 | 卡片式操作列表 |

**关键 CSS**：

```css
/* Google 风格搜索框 */
.google-search-container {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

.google-search-input {
  width: 100%;
  max-width: 580px;
  padding: 16px 20px;
  font-size: 16px;
  border-radius: 24px;
  border: 1px solid #333;
}

/* 卡片网格 */
.tool-cards-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 20px;
}

.tool-card {
  background: #0f3460;
  border-radius: 12px;
  padding: 20px;
  cursor: pointer;
  transition: all 0.3s;
}

.tool-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.3);
}
```

---

## 五、协作模式总结

### 5.1 角色分工

| 角色 | 职责 | 工具 |
|------|------|------|
| Trae (我) | 设计、分析、决策、审查 | Trae IDE |
| 龙虾 (OpenClaw) | 执行、操作、实现 | OpenClaw Agent |

### 5.2 协作流程

```
1. 我分析需求 → 设计方案
2. 我调用龙虾 → 执行具体操作
3. 龙虾返回结果 → 我审查完善
4. 共同提交代码
```

### 5.3 龙虾的优势

- ✅ 直接执行 Shell 命令（无需 approval）
- ✅ 直接读写文件
- ✅ GitHub CLI 集成
- ✅ 飞书消息发送
- ✅ 网页抓取和截图
- ✅ 定时任务管理

### 5.4 最佳实践

1. **明确指令**：给龙虾的 prompt 要清晰具体
2. **错误处理**：始终处理 JSON 解析失败的情况
3. **配置同步**：保持 CoffeeClaw 和 OpenClaw 配置一致
4. **渐进增强**：先实现基础功能，再优化 UI
5. **用户反馈**：根据用户反馈迭代设计

---

## 六、成果展示

### 6.1 功能清单

| 分类 | 功能数量 | 实现方式 |
|------|----------|----------|
| Web 搜索 | 2 | OpenClaw Agent |
| GitHub | 6 | gh CLI + OpenClaw |
| 飞书 | 4 | OpenClaw Feishu 插件 |
| 文件管理 | 4 | OpenClaw 文件工具 |
| 系统工具 | 6 | Shell + OpenClaw |

### 6.2 代码统计

```
Commits: 15+
Files changed: 10+
Lines added: 1500+
Lines removed: 200+
```

### 6.3 技术栈

- Electron + CoffeeScript
- OpenClaw Agent Framework
- OpenRouter API
- 飞书开放平台

---

## 七、心得体会

### 7.1 协作的力量

与龙虾协作开发，让我深刻体会到"借力"的重要性。原本需要数周开发的功能，在龙虾的帮助下，几天就完成了核心集成。

### 7.2 配置管理的艺术

多系统配置同步是一个容易被忽视但极其重要的问题。通过时间戳比较和自动同步，我们解决了这个痛点。

### 7.3 用户体验至上

技术实现只是第一步，真正让用户满意的是熟悉的界面、流畅的交互。Google 风格的搜索框、GitHub 风格的卡片，这些"小细节"大大提升了用户好感度。

### 7.4 持续迭代

没有完美的第一版。通过用户反馈，我们不断发现问题、解决问题、优化体验。JSON 解析、配置同步、UI 重构，每一次迭代都让产品更好。

---

## 八、未来展望

- [ ] 流式输出支持
- [ ] 更多 AI 模型集成
- [ ] 插件系统
- [ ] 语音交互
- [ ] 多语言优化

---

**结语**：与龙虾的协作，是一次技术与创意的碰撞。它让我明白，好的工具不是替代开发者，而是放大开发者的能力。期待未来更多的协作可能！

---

*文档版本: 1.0.0*  
*最后更新: 2026-03-10*  
*作者: CoffeeClaw Team*
