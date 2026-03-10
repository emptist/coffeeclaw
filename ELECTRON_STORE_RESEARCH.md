# Electron Store 研究报告

## 官方推荐方案

**electron-store** 是 Electron 官方推荐的数据持久化方案，由 Sindre Sorhus（知名开源作者）开发。

## 基本信息

- **作者**: Sindre Sorhus
- **GitHub**: https://github.com/sindresorhus/electron-store
- **用途**: Electron 应用数据持久化
- **格式**: JSON
- **存储位置**: `app.getPath('userData')`

## 核心特性

### 1. 专为 Electron 设计
- 自动处理跨平台路径差异（Windows/macOS/Linux）
- 数据存储在用户数据目录
- 支持主进程和渲染进程

### 2. 原子写入
- 使用原子文件操作，避免数据损坏
- 写入失败时保留旧数据

### 3. 简单易用的 API
```javascript
const Store = require('electron-store');
const store = new Store();

// 设置值
store.set('unicorn', '🦄');

// 获取值
console.log(store.get('unicorn'));  // '🦄'

// 嵌套对象
store.set('foo.bar', true);
console.log(store.get('foo'));  // { bar: true }

// 删除
store.delete('unicorn');
```

### 4. 支持默认值和 Schema 验证
```javascript
const Store = require('electron-store');

const store = new Store({
  defaults: {
    windowBounds: { width: 800, height: 600 }
  },
  schema: {
    windowBounds: {
      type: 'object',
      properties: {
        width: { type: 'number', minimum: 100 },
        height: { type: 'number', minimum: 100 }
      }
    }
  }
});
```

### 5. 支持加密
```javascript
const Store = require('electron-store');

const store = new Store({
  encryptionKey: 'my-secret-key'  // 加密存储敏感数据
});
```

## 与 LowDB 对比

| 特性 | electron-store | LowDB |
|------|----------------|-------|
| **官方支持** | ✅ Electron 官方推荐 | 社区库 |
| **作者** | Sindre Sorhus (知名) | Typicode |
| **跨平台** | ✅ 自动处理 | 需手动处理路径 |
| **原子写入** | ✅ 内置 | 依赖 steno |
| **API 复杂度** | 简单 (get/set/delete) | 中等 (需手动管理 data) |
| **数组操作** | 手动 | 原生支持 |
| **查询功能** | 无 | 可用 lodash 扩展 |
| **Schema 验证** | ✅ 内置 | 需自行实现 |
| **加密** | ✅ 内置 | 需自行实现 |
| **TypeScript** | ✅ 支持 | ✅ 支持 |
| **文件位置** | userData 目录 | 自定义 |

## 适用场景

### electron-store 适合：
- 应用配置（settings/preferences）
- 用户偏好（主题、窗口大小等）
- 小型键值对数据
- 需要 Schema 验证的数据

### LowDB 适合：
- 数组/列表数据（bots, messages）
- 需要复杂查询
- 类数据库操作
- 需要自定义文件位置

## 使用示例

### 基础使用
```javascript
const Store = require('electron-store');

const store = new Store({
  name: 'coffeeclaw-data',  // 文件名
  defaults: {
    settings: {
      token: null,
      apiKey: null,
      activeProvider: 'zhipu'
    },
    bots: [],
    activeBotId: null
  }
});

// 保存 bot
const bots = store.get('bots');
bots.push({ id: 'bot1', name: 'Assistant', model: 'glm-4-flash' });
store.set('bots', bots);

// 读取 bot
const allBots = store.get('bots');
const activeBotId = store.get('activeBotId');
```

### 在 CoffeeScript 中使用
```coffee
Store = require 'electron-store'

class CoffeeClawStore
  constructor: ->
    @store = new Store
      name: 'coffeeclaw-data'
      defaults:
        settings:
          token: null
          apiKey: null
          activeProvider: 'zhipu'
        bots: []
        sessions: {}
        activeBotId: null
  
  # Bot 操作
  getBots: -> @store.get('bots')
  
  saveBot: (bot) ->
    bots = @getBots()
    index = bots.findIndex (b) -> b.id is bot.id
    if index >= 0
      bots[index] = bot
    else
      bots.push(bot)
    @store.set('bots', bots)
  
  getActiveBotId: -> @store.get('activeBotId')
  setActiveBotId: (id) -> @store.set('activeBotId', id)
  
  # Settings 操作
  getSettings: -> @store.get('settings')
  saveSettings: (settings) -> @store.set('settings', settings)
  
  # Session 操作
  getSession: (id) -> @store.get("sessions.#{id}")
  saveSession: (id, session) -> @store.set("sessions.#{id}", session)
```

## 文件位置

### 各平台存储路径
- **Windows**: `%APPDATA%/<app-name>/coffeeclaw-data.json`
- **macOS**: `~/Library/Application Support/<app-name>/coffeeclaw-data.json`
- **Linux**: `~/.config/<app-name>/coffeeclaw-data.json`

### 与 LowDB 对比
- **electron-store**: 标准用户数据目录，符合各平台规范
- **LowDB**: 项目目录下的 `.secrete/db.json`，便于开发时查看

## 迁移考虑

### 从 LowDB 迁移到 electron-store

**优点**:
1. 更符合 Electron 生态
2. 自动跨平台路径处理
3. 内置 Schema 验证
4. 支持加密

**缺点**:
1. 需要重写 Database 类
2. 文件位置改变（从项目目录到 userData）
3. 数组操作不如 LowDB 方便

### 混合方案
可以同时使用两者：
- **electron-store**: settings, preferences
- **LowDB**: bots, sessions（数组数据）

## 结论

**electron-store 是更好的选择**，原因：

1. ✅ **官方推荐**: Electron 生态标准方案
2. ✅ **成熟稳定**: Sindre Sorhus 维护，广泛使用
3. ✅ **功能完善**: Schema、加密、原子写入
4. ✅ **跨平台**: 自动处理路径差异
5. ✅ **简单**: API 更简洁

**建议**: 使用 electron-store 替代 LowDB

**实施计划**:
1. 安装 electron-store
2. 创建 CoffeeClawStore 类封装操作
3. 实现 toJSON/fromJSON 序列化
4. 迁移现有数据
5. 测试验证
