# CoffeeClaw

## 概述

CoffeeClaw 是一个与 OpenClaw 深度集成的 AI 助手应用，专注于编程辅助和内容创作，帮助用户产生经济效益。

通过整合 OpenClaw 的记忆系统和 CoffeeClaw 的增强功能，我们提供了一个强大的创作和开发环境。

## 技术栈

- **前端**: Electron + HTML/CSS/JavaScript
- **后端**: Node.js + CoffeeScript
- **AI 集成**: OpenClaw Gateway + 多模型支持 (GLM-4-Flash, OpenRouter)
- **存储**: Electron Store + 文件系统
- **架构**: MVVM + Protocol-Oriented Programming

## 目录结构

```
coffeeclaw/
├── .openclaw/                    # 项目记忆文件
│   ├── CONTEXT.md                # 当前上下文
│   ├── DECISIONS.md              # 决策记录
│   ├── MEMORY.md                 # 项目记忆
│   ├── PROGRESS.md               # 进度追踪
│   ├── PROJECT.md                # 项目概述 (本文件)
│   └── TODO.md                   # 待办事项
│
├── .trae/                        # Trae IDE 配置
│   └── rules/
│       └── project_rules.md      # 项目规则
│
├── assets/                       # 静态资源
├── data/                         # 数据文件
│   └── economic/                 # 经济效益追踪数据
│
├── documents/                    # 文档目录
│   ├── COFFEECLAW_OPENCLAW_INTEGRATION_PLAN.md  # 集成方案
│   └── ...                       # 其他文档
│
├── memory/                       # 记忆文件
├── scripts/                      # 脚本文件
│   └── install-skills.sh         # 技能安装脚本
│
├── skills/                       # OpenClaw 技能
│   ├── content-creator/          # 内容创作技能
│   ├── economic-tracker/         # 经济效益追踪技能
│   └── memory-enhancer/          # 记忆增强技能
│
├── src/                          # 源代码
│   ├── core/                     # 核心模块
│   │   ├── memory-sync.coffee    # 记忆同步器
│   │   ├── typed-storage.coffee  # 类型化存储
│   │   └── storage.coffee        # 存储管理
│   │
│   ├── openclaw-manager.coffee   # OpenClaw 管理器
│   ├── openclaw-config.coffee    # OpenClaw 配置
│   ├── ipc-handlers.coffee       # IPC 处理器
│   └── ...                       # 其他模块
│
├── chat.coffee                   # 聊天逻辑
├── index.html                    # 主界面
├── package.json                  # 项目配置
└── README.md                     # 项目说明
```

## 关键模块

### 1. MemorySync (记忆同步器)
- 双向同步 OpenClaw 和 CoffeeClaw 的记忆文件
- 文件监听和自动同步
- 冲突解决机制

### 2. OpenClawManager (OpenClaw 管理器)
- 管理 OpenClaw 网关连接
- 代理调用和配置管理
- 会话管理

### 3. Content Creator (内容创作)
- 技术文档生成
- 视频脚本创作
- 营销文案优化

### 4. Economic Tracker (经济效益追踪)
- 项目收益记录
- 时间成本统计
- ROI 分析

### 5. Memory Enhancer (记忆增强)
- 自动标签分类
- 关键信息提取
- 智能搜索

## OpenClaw 集成

CoffeeClaw 与 OpenClaw 深度集成：

1. **记忆同步**: 双向同步 `~/.openclaw/.openclaw/` 和项目记忆
2. **技能扩展**: 提供专属技能扩展 OpenClaw 能力
3. **会话共享**: 读取和利用 OpenClaw 会话历史
4. **配置管理**: 统一管理 OpenClaw 配置

## 开发指南

### 安装依赖
```bash
cd ~/.openclaw/workspace/coffeeclaw
cnpm install
```

### 编译 CoffeeScript
```bash
npm run build
# 或
npx coffee -c src/
```

### 开发模式
```bash
npm run dev
# 或
npm start
```

### 安装技能到 OpenClaw
```bash
./scripts/install-skills.sh
```

### 测试
```bash
npm test
```

### 打包
```bash
npm run package
# 或
npm run make
```

## 经济效益

CoffeeClaw 帮助用户产生经济效益的方式：

- **内容创作**: 技术文档代写 (¥500-2000/篇)
- **脚本创作**: 视频脚本 (¥300-1000/个)
- **文案优化**: 产品文案 (¥200-500/篇)
- **开发效率**: 代码生成和优化
- **咨询服务**: AI 工具配置咨询

## 相关链接

- [集成方案文档](documents/COFFEECLAW_OPENCLAW_INTEGRATION_PLAN.md)
- [架构文档](documents/ARCHITECTURE.md)
- [开发者指南](documents/DEVELOPER_GUIDE.md)

## 版本历史

- **v0.1.0** - 基础 OpenClaw 集成
- **v0.2.0** - MemorySync 记忆同步
- **v0.3.0** - 内容创作技能
- **v0.4.0** - 经济效益追踪

---

**项目状态**: 活跃开发中
**最后更新**: 2026-03-13
