# Model 类和架构重构计划

## 分支
`refactor/model-classes`

## 目标
解决模型 ID 格式混乱问题，统一模型管理，使用专业的 JSON 数据库，建立清晰的类层次结构。

## 背景
当前代码中模型 ID 处理混乱：
- Zhipu API 需要 `glm-4-flash`（不带前缀）
- OpenClaw 配置需要 `glm/glm-4-flash`（带前缀）
- 存储时只保存字符串，丢失 provider 信息
- 导致切换 provider 时出现 `anthropic/glm-4-flash` 错误

## 新增类清单

### 1. Model 类层次结构 (`src/model.coffee`)

#### Model（基类）
```coffee
class Model
  constructor: (@id, @provider) ->
  
  rawId: -> @id
  fullId: -> "#{@provider}/#{@id}"
  apiId: -> @id
  openClawId: -> @fullId()
  
  toJSON: -> { @id, @provider }
  
  @fromJSON: (data) ->
    if typeof data is 'string'
      ModelFactory.createFromString(data)
    else
      ModelFactory.create(data.provider, data.id)
```

#### ZhipuModel
- `apiId()`: `glm-4-flash`（API 调用）
- `openClawId()`: `glm/glm-4-flash`（OpenClaw 配置）

#### OpenRouterModel
- 处理已带前缀的 ID（如 `google/gemini-2.0-flash`）

#### DeepSeekModel
- `apiId()`: `deepseek-chat`
- `openClawId()`: `deepseek/deepseek-chat`

#### OpenAIModel
- `apiId()`: `gpt-4o`
- `openClawId()`: `openai/gpt-4o`

#### ModelFactory
```coffee
class ModelFactory
  @PROVIDER_MAP =
    zhipu: 'glm'
    openrouter: 'openrouter'
    deepseek: 'deepseek'
    openai: 'openai'
  
  @create: (provider, id) ->
    switch provider
      when 'zhipu' then new ZhipuModel(id)
      when 'openrouter' then new OpenRouterModel(id)
      when 'deepseek' then new DeepSeekModel(id)
      when 'openai' then new OpenAIModel(id)
      else new Model(id, provider)
  
  @createFromString: (str) ->
    if str.includes('/')
      [provider, id] = str.split('/')
      @create(provider, id)
    else
      # 需要根据上下文推断 provider
      @create(null, str)
```

### 2. Provider 类 (`src/provider.coffee`)

```coffee
class Provider
  constructor: (@id, @name, @baseUrl, @apiPath) ->
  
  createModel: (modelId) -> ModelFactory.create(@id, modelId)
  getOpenClawName: -> ModelFactory.PROVIDER_MAP[@id]

class ZhipuProvider extends Provider
  constructor: ->
    super('zhipu', 'Zhipu GLM', 'open.bigmodel.cn', '/api/paas/v4/chat/completions')

class OpenRouterProvider extends Provider
  constructor: ->
    super('openrouter', 'OpenRouter', 'openrouter.ai', '/api/v1/chat/completions')

class DeepSeekProvider extends Provider
  constructor: ->
    super('deepseek', 'DeepSeek', 'api.deepseek.com', '/v1/chat/completions')

class OpenAIProvider extends Provider
  constructor: ->
    super('openai', 'OpenAI', 'api.openai.com', '/v1/chat/completions')
```

### 3. OpenClawConfig 类 (`src/openclaw-config.coffee`)

```coffee
class OpenClawConfig
  CONFIG_PATH: '~/.openclaw/openclaw.json'
  
  constructor: ->
    @data = @load()
  
  load: ->
    # 读取 ~/.openclaw/openclaw.json
  
  setModel: (model) ->
    @data.agents.defaults.model.primary = model.openClawId()
  
  setProvider: (provider, apiKey) ->
    openClawName = provider.getOpenClawName()
    @data.models.providers[openClawName] =
      baseUrl: "https://#{provider.baseUrl}#{provider.apiPath}".replace('/chat/completions', '')
      apiKey: apiKey
      api: 'openai-completions'
      models: [] # 从 MODELS 获取
  
  setToken: (token) ->
    @data.gateway.auth.token = token
    @data.gateway.remote?.token = token
  
  save: ->
    # 写入文件
```

### 4. FeishuConfig 类 (`src/feishu-config.coffee`)

```coffee
class FeishuConfig
  constructor: (@appId = '', @appSecret = '', @botName = 'CoffeeClaw') ->
    @enabled = false
    @dmPolicy = 'pairing'
    @groupPolicy = 'open'
  
  toJSON: ->
    { @enabled, @appId, @appSecret, @botName, @dmPolicy, @groupPolicy }
  
  @fromJSON: (data) ->
    config = new FeishuConfig(data.appId, data.appSecret, data.botName)
    config.enabled = data.enabled
    config.dmPolicy = data.dmPolicy ? 'pairing'
    config.groupPolicy = data.groupPolicy ? 'open'
    config
```

### 5. Bot 类 (`src/bot.coffee`)

```coffee
class Bot
  constructor: (@id, @name, @description, @model, @systemPrompt, @skills) ->
    @enabled = true
    @createdAt = new Date().toISOString()
    @updatedAt = @createdAt
  
  isAgent: -> @model?.rawId() == 'openclaw-agent'
  
  update: (changes) ->
    for key, value of changes
      @[key] = value if @[key]?
    @updatedAt = new Date().toISOString()
  
  toJSON: ->
    {
      @id, @name, @description
      model: @model.toJSON()
      @systemPrompt, @skills
      @enabled, @createdAt, @updatedAt
    }
  
  @fromJSON: (data) ->
    model = Model.fromJSON(data.model)
    bot = new Bot(data.id, data.name, data.description, model, data.systemPrompt, data.skills)
    bot.enabled = data.enabled
    bot.createdAt = data.createdAt
    bot.updatedAt = data.updatedAt
    bot
```

### 6. Session 类 (`src/session.coffee`)

```coffee
class Session
  constructor: (@id, @botId) ->
    @messages = []
    @createdAt = new Date().toISOString()
    @updatedAt = @createdAt
  
  addMessage: (role, content) ->
    @messages.push
      role: role
      content: content
      timestamp: Date.now()
    @updatedAt = new Date().toISOString()
  
  toJSON: ->
    { @id, @botId, @messages, @createdAt, @updatedAt }
  
  @fromJSON: (data) ->
    session = new Session(data.id, data.botId)
    session.messages = data.messages
    session.createdAt = data.createdAt
    session.updatedAt = data.updatedAt
    session
```

### 7. Settings 类 (`src/settings.coffee`)

```coffee
class Settings
  constructor: ->
    @token = null
    @apiKey = null
    @activeProvider = 'zhipu'
    @providers = {}  # providerId -> { apiKey, model }
    @feishu = new FeishuConfig()
  
  getProvider: (id) -> @providers[id]
  
  setProvider: (provider, apiKey, model) ->
    @providers[provider.id] =
      apiKey: apiKey
      model: model
  
  getActiveProvider: -> @providers[@activeProvider]
  
  toJSON: ->
    {
      @token, @apiKey, @activeProvider
      providers: @providers
      feishu: @feishu.toJSON()
    }
  
  @fromJSON: (data) ->
    settings = new Settings()
    settings.token = data.token
    settings.apiKey = data.apiKey
    settings.activeProvider = data.activeProvider ? 'zhipu'
    settings.providers = data.providers ? {}
    settings.feishu = FeishuConfig.fromJSON(data.feishu ? {})
    settings
```

### 8. Database 类 (`src/database.coffee`)

```coffee
{ Low } = require 'lowdb'
{ JSONFile } = require 'lowdb/node'

class Database
  constructor: (filePath) ->
    @adapter = new JSONFile(filePath)
    @db = new Low(@adapter)
  
  init: ->
    await @db.read()
    @db.data = @db.data or {}
  
  # Bots
  getBots: ->
    (@db.data.bots ? []).map (b) -> Bot.fromJSON(b)
  
  getBot: (id) ->
    data = @db.data.bots?.find (b) -> b.id is id
    Bot.fromJSON(data) if data
  
  getActiveBot: ->
    @getBot(@db.data.activeBotId)
  
  saveBot: (bot) ->
    @db.data.bots = @db.data.bots or []
    json = bot.toJSON()
    index = @db.data.bots.findIndex (b) -> b.id is bot.id
    if index >= 0
      @db.data.bots[index] = json
    else
      @db.data.bots.push(json)
    await @db.write()
  
  setActiveBot: (id) ->
    @db.data.activeBotId = id
    await @db.write()
  
  # Settings
  getSettings: ->
    Settings.fromJSON(@db.data.settings ? {})
  
  saveSettings: (settings) ->
    @db.data.settings = settings.toJSON()
    await @db.write()
  
  # Sessions
  getSession: (id) ->
    data = @db.data.sessions?[id]
    Session.fromJSON(data) if data
  
  saveSession: (session) ->
    @db.data.sessions = @db.data.sessions or {}
    @db.data.sessions[session.id] = session.toJSON()
    await @db.write()
```

## 数据库存储策略

| 类 | 存储方式 | 文件 | 原因 |
|---|---|---|---|
| Bot | LowDB | `.secrete/db.json` | 用户创建，需要持久化 |
| Settings | LowDB | `.secrete/db.json` | 应用配置，需要持久化 |
| Session | LowDB | `.secrete/db.json` | 聊天记录，需要持久化 |
| Model | 不存储 | - | 运行时创建，从字符串解析 |
| Provider | 不存储 | - | 运行时创建，代码定义 |
| OpenClawConfig | 单独文件 | `~/.openclaw/openclaw.json` | OpenClaw 需要独立配置 |
| FeishuConfig | LowDB | `.secrete/db.json` | 作为 Settings 的一部分 |

## 实施步骤

### Phase 1: 基础类
1. [ ] 安装 lowdb
2. [ ] 创建 `src/model.coffee`
3. [ ] 创建 `src/provider.coffee`
4. [ ] 编写测试验证 Model 和 Provider 类

### Phase 2: 配置类
5. [ ] 创建 `src/openclaw-config.coffee`
6. [ ] 创建 `src/feishu-config.coffee`
7. [ ] 编写测试验证配置类

### Phase 3: 实体类
8. [ ] 创建 `src/bot.coffee`
9. [ ] 创建 `src/session.coffee`
10. [ ] 创建 `src/settings.coffee`
11. [ ] 编写测试验证实体类

### Phase 4: 数据库层
12. [ ] 创建 `src/database.coffee`
13. [ ] 编写测试验证数据库操作

### Phase 5: 整合
14. [ ] 修改 `src/main.coffee` 使用新类
15. [ ] 迁移现有数据（bots.json, settings.json, sessions.json）
16. [ ] 全面测试

### Phase 6: 清理
17. [ ] 删除旧的文件操作代码
18. [ ] 删除临时文件（bots.json, settings.json 等）
19. [ ] 更新文档

## 风险

1. **数据迁移失败**：需要备份现有数据
2. **遗漏的使用处**：需要全面检查代码
3. **性能影响**：LowDB 是异步的，需要正确处理 async/await
4. **向后兼容性**：需要支持从旧格式迁移

## 备份策略

在实施前备份：
- `.secrete/settings.json`
- `.secrete/bots.json`
- `.secrete/sessions.json`
- `.secrete/license.json`
- `~/.openclaw/openclaw.json`

## 测试计划

1. **单元测试**：每个类的 toJSON/fromJSON
2. **集成测试**：Database 的 CRUD 操作
3. **端到端测试**：
   - 创建 bot，保存，读取
   - 发送消息，保存 session
   - 切换 provider，保存 settings
   - OpenClaw Agent 调用
