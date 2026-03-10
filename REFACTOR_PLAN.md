# Model 类和 LowDB 重构计划

## 目标
解决模型 ID 格式混乱问题，统一模型管理，使用专业的 JSON 数据库。

## 背景
当前代码中模型 ID 处理混乱：
- Zhipu API 需要 `glm-4-flash`（不带前缀）
- OpenClaw 配置需要 `glm/glm-4-flash`（带前缀）
- 存储时只保存字符串，丢失 provider 信息
- 导致切换 provider 时出现 `anthropic/glm-4-flash` 错误

## 要做的更改

### 1. 安装依赖
```bash
npm install lowdb
```
**原因**：替代手动读写 JSON 文件，自动处理对象序列化/反序列化

### 2. 创建 `src/model.coffee`
定义 Model 类层次结构：

#### Model 基类
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

#### 子类
- **ZhipuModel**：处理 `glm-4-flash` → `glm/glm-4-flash`
- **OpenRouterModel**：处理已带前缀的模型 ID（如 `google/gemini-2.0-flash`）
- **DeepSeekModel**：处理 `deepseek-chat` → `deepseek/deepseek-chat`
- **OpenAIModel**：处理 `gpt-4o` → `openai/gpt-4o`

#### ModelFactory 工厂类
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
    # 解析 "provider/id" 或 "id" 格式
    if str.includes('/')
      [provider, id] = str.split('/')
      @create(provider, id)
    else
      # 需要根据上下文推断 provider
      @create(null, str)
```

**原因**：封装不同 provider 的格式差异，避免散落在各处

### 3. 创建 `src/database.coffee`
封装 LowDB 操作：

```coffee
{ Low } = require 'lowdb'
{ JSONFile } = require 'lowdb/node'

class Database
  constructor: (@filePath) ->
    @adapter = new JSONFile(@filePath)
    @db = new Low(@adapter)
  
  init: ->
    await @db.read()
    @db.data = @db.data or {}
  
  # Bots
  getBots: -> @db.data.bots or []
  saveBot: (bot) ->
    @db.data.bots = @db.data.bots or []
    existing = @db.data.bots.find (b) -> b.id is bot.id
    if existing
      Object.assign(existing, bot)
    else
      @db.data.bots.push(bot)
    await @db.write()
  
  # Settings
  getSettings: -> @db.data.settings or {}
  saveSettings: (settings) ->
    @db.data.settings = settings
    await @db.write()
  
  # Sessions
  getSessions: -> @db.data.sessions or {}
  saveSession: (id, session) ->
    @db.data.sessions = @db.data.sessions or {}
    @db.data.sessions[id] = session
    await @db.write()
```

**原因**：统一数据访问层，支持存储完整 Model 对象

### 4. 修改 `src/main.coffee`

#### 替换导入
```coffee
{ Model, ModelFactory } = require './model'
{ Database } = require './database'
```

#### 替换手动文件操作
```coffee
# 旧代码
loadBots = ->
  try
    if fs.existsSync botsFile
      data = fs.readFileSync botsFile, 'utf8'
      return JSON.parse data
  catch e
    console.error 'Error loading bots:', e
  { bots: [], activeBotId: null }

# 新代码
db = new Database(path.join(secreteDir, 'db.json'))
await db.init()

loadBots = ->
  { bots: db.getBots(), activeBotId: db.data.activeBotId }
```

#### 替换字符串 model
```coffee
# 旧代码
callAPI = (sessionId, message, settings, bot = null) ->
  model = bot?.model or settings.model or 'glm-4-flash'
  # ...
  postData =
    model: model  # 字符串
    messages: messages

# 新代码
callAPI = (sessionId, message, settings, bot = null) ->
  model = if bot?.model
    Model.fromJSON(bot.model)  # Model 对象
  else
    ModelFactory.create(settings.activeProvider, settings.model or 'glm-4-flash')
  # ...
  postData =
    model: model.apiId()  # 使用 apiId()
    messages: messages
```

#### 修改 syncProvidersToOpenClaw
```coffee
# 旧代码
modelId = providerData.model
unless modelId.startsWith(openClawProvider)
  modelId = "#{openClawProvider}/#{modelId}"
config.agents.defaults.model.primary = modelId

# 新代码
model = ModelFactory.create(activeProvider, providerData.model)
config.agents.defaults.model.primary = model.openClawId()
```

**原因**：统一使用 Model 类，消除格式转换错误

### 5. 数据迁移

#### 迁移 bots.json
```coffee
migrateBots = ->
  oldData = loadBotsOld()  # 使用旧的加载方式
  for bot in oldData.bots
    if typeof bot.model is 'string'
      # 推断 provider
      provider = inferProvider(bot.model)
      bot.model = { id: bot.model, provider }
  await db.saveBot(bot) for bot in oldData.bots
  db.data.activeBotId = oldData.activeBotId
  await db.write()
```

**原因**：向后兼容，保留现有数据

#### 迁移 settings.json
```coffee
migrateSettings = ->
  oldSettings = loadSettingsOld()
  # 转换 providers 中的 model
  for provider, config of oldSettings.providers
    if typeof config.model is 'string'
      config.model = { id: config.model, provider }
  await db.saveSettings(oldSettings)
```

### 6. 测试验证

- [ ] 验证 Code Helper bot 正常工作
- [ ] 验证 OpenClaw Agent 正常工作
- [ ] 验证切换 provider 时模型解析正确
- [ ] 验证数据迁移后无丢失

## 风险

1. **数据迁移失败**：需要备份现有数据
2. **遗漏的 model 使用处**：需要全面检查代码
3. **性能影响**：LowDB 是同步还是异步？需要确认

## 实施顺序

1. [ ] 安装 lowdb
2. [ ] 创建 model.coffee（不修改 main.coffee）
3. [ ] 创建 database.coffee（不修改 main.coffee）
4. [ ] 编写测试验证 Model 类
5. [ ] 修改 main.coffee 使用新类
6. [ ] 数据迁移
7. [ ] 全面测试

## 备份策略

在实施前备份：
- `.secrete/settings.json`
- `.secrete/bots.json`
- `.secrete/sessions.json`
- `~/.openclaw/openclaw.json`
