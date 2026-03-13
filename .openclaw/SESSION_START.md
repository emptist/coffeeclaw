# 对话启动文档

## 当前状态

### 已完成工作 (2026-03-13)

1. **OpenClaw 架构分析**
   - 探索了 OpenClaw 目录结构和记忆系统
   - 分析了记忆文件格式 (Markdown + JSONL)
   - 理解了技能系统机制

2. **集成方案设计**
   - 创建了完整的集成方案文档
   - 设计了三阶段实施计划
   - 定义了经济效益目标

3. **核心模块开发**
   - 实现了 MemorySync 记忆同步器
   - 支持双向同步 OpenClaw 和 CoffeeClaw 记忆
   - 实现了文件监听和冲突解决

4. **CoffeeClaw 专属技能**
   - content-creator: 内容创作助手
   - economic-tracker: 经济效益追踪
   - memory-enhancer: 记忆增强器
   - 所有技能已安装到 `~/.openclaw/extensions/coffeeclaw/skills/`

5. **OpenClaw 集成**
   - OpenClaw 网关运行在端口 18789
   - 技能文件已成功安装
   - 网关已重启加载新技能

6. **代码重构 (进行中)**
   - 将 `backup()` 方法迁移到 OpenClawConfig 类
   - 将 `syncFromSettings()` 方法迁移到 OpenClawConfig 类
   - 正在更新 main.coffee 使用类方法

7. **文档和 Git**
   - 更新了 PROJECT.md
   - 更新了 PROGRESS.md
   - Git commit: 9edd0a2

## 技术架构

### OpenClaw 配置
- 位置: `~/.openclaw/openclaw.json`
- 默认模型: `glm/GLM-4-Flash` (需要切换到 OpenRouter)
- 提供商: GLM, OpenRouter, DeepSeek

### CoffeeClaw 配置
- 位置: `~/.openclaw/workspace/coffeeclaw/`
- 技能目录: `skills/`
- 记忆目录: `.openclaw/`

### 协作模式
- **龙虾 (GLM-4-Flash)**: 指导和决策，不能直接执行文件操作
- **OpenRouter**: 可以直接执行文件操作和调用工具
- **CoffeeClaw 助手**: 负责执行具体操作和代码重构

## 下一步任务

1. **完成代码重构**
   - [ ] 替换 main.coffee 中的 `backupOpenClawConfig()` 为 `config.backup()`
   - [ ] 移除 `getBackupManager()` 和 `backupManagerInstance`
   - [ ] 测试重构后的代码

2. **切换 OpenClaw 默认模型**
   - [ ] 使用 OpenClawConfig.setPrimaryModel() 切换到 OpenRouter
   - [ ] 验证切换成功

3. **测试技能功能**
   - [ ] 测试 content-creator 技能
   - [ ] 测试 economic-tracker 技能
   - [ ] 测试 memory-enhancer 技能

4. **集成 MemorySync 到 UI**
   - [ ] 在 CoffeeClaw UI 中添加记忆同步功能
   - [ ] 添加记忆浏览器界面
   - [ ] 添加技能管理界面

5. **经济效益功能**
   - [ ] 实现项目收益记录
   - [ ] 实现时间追踪
   - [ ] 实现 ROI 分析

## 关键文件

- [集成方案](documents/COFFEECLAW_OPENCLAW_INTEGRATION_PLAN.md)
- [MemorySync 模块](src/core/memory-sync.coffee)
- [OpenClawConfig](src/openclaw-config.coffee)
- [技能文件](skills/)
- [项目进度](.openclaw/PROGRESS.md)

## 注意事项

1. **遵循 OOP 原则**
   - 将分散的函数迁移到对应的 class 中
   - 使用 class 方法而不是全局函数
   - 保持代码的可维护性和可测试性

2. **Git Commit 规则**
   - 每完成一个功能就 commit
   - 写清晰的 commit message
   - 不要混合多个功能在一个 commit

3. **与 OpenClaw 协作**
   - 龙虾 (GLM-4-Flash) 用于指导
   - OpenRouter 用于执行操作
   - 通过对话协调工作

---

**创建时间**: 2026-03-13
**对话模式**: Solo 模式
