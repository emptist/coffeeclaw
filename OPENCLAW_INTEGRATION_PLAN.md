# OpenClaw 功能集成计划

## 目标

将 OpenClaw 的所有功能集成到 CoffeeClaw，实现"一个应用解决一切"。

## OpenClaw 可用工具

| 工具 | 功能 | 集成优先级 |
|------|------|-----------|
| exec | 执行命令 | P0 |
| read | 读取文件 | P0 |
| write | 写入文件 | P0 |
| edit | 编辑文件 | P0 |
| web_search | 网络搜索 | P1 |
| web_fetch | 获取网页 | P1 |
| browser | 浏览器自动化 | P2 |
| cron | 定时任务 | P1 |
| message | 消息发送 | P1 |
| tts | 语音合成 | P2 |
| gateway | 网关管理 | P2 |
| memory_* | 记忆管理 | P2 |
| sessions_* | 会话管理 | P2 |

## OpenClaw 可用技能

| 技能 | 功能 | 集成优先级 |
|------|------|-----------|
| github | GitHub 操作 | P1 |
| gh-issues | GitHub Issues | P1 |
| feishu-doc | 飞书文档 | P1 |
| feishu-drive | 飞书云盘 | P1 |
| feishu-wiki | 飞书知识库 | P1 |
| feishu-perm | 飞书权限 | P1 |
| weather | 天气查询 | P2 |
| coding-agent | 编码助手 | P2 |
| healthcheck | 健康检查 | P2 |
| session-logs | 会话日志 | P2 |
| skill-creator | 技能创建 | P2 |

## 集成架构

```
┌─────────────────────────────────────────────────────────┐
│                    CoffeeClaw UI                        │
│  ┌─────────────────────────────────────────────────┐   │
│  │              OpenClaw 工具箱                      │   │
│  │  ┌─────┬─────┬─────┬─────┬─────┬─────┬─────┐   │   │
│  │  │exec │read │write│edit │web  │cron │more │   │   │
│  │  └─────┴─────┴─────┴─────┴─────┴─────┴─────┘   │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                    Main Process                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │            IPC Handlers                          │   │
│  │  - openclaw-exec                                 │   │
│  │  - openclaw-read                                 │   │
│  │  - openclaw-write                                │   │
│  │  - openclaw-edit                                 │   │
│  │  - openclaw-web-search                           │   │
│  │  - openclaw-web-fetch                            │   │
│  │  - ...                                           │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                  OpenClaw Agent                         │
│  openclaw agent --local --message "..." --json         │
└─────────────────────────────────────────────────────────┘
```

## Phase 1: 核心工具集成

### 1.1 文件操作

- [ ] 添加 IPC: `openclaw-read-file`
- [ ] 添加 IPC: `openclaw-write-file`
- [ ] 添加 IPC: `openclaw-edit-file`
- [ ] 更新 UI: 文件操作面板

### 1.2 命令执行

- [x] 添加 IPC: `run-local-command` (已完成)
- [ ] 增强: 支持 OpenClaw exec 工具
- [ ] 更新 UI: 命令执行面板

## Phase 2: GitHub 集成

- [ ] 添加 IPC: `openclaw-github-issues`
- [ ] 添加 IPC: `openclaw-github-pr`
- [ ] 添加 IPC: `openclaw-github-repo`
- [ ] 更新 UI: GitHub 面板

## Phase 3: 网络功能

- [ ] 添加 IPC: `openclaw-web-search`
- [ ] 添加 IPC: `openclaw-web-fetch`
- [ ] 更新 UI: 搜索面板

## Phase 4: 飞书集成

- [ ] 添加 IPC: `openclaw-feishu-message`
- [ ] 添加 IPC: `openclaw-feishu-doc`
- [ ] 添加 IPC: `openclaw-feishu-drive`
- [ ] 更新 UI: 飞书面板

## Phase 5: 定时任务

- [ ] 添加 IPC: `openclaw-cron-create`
- [ ] 添加 IPC: `openclaw-cron-list`
- [ ] 添加 IPC: `openclaw-cron-delete`
- [ ] 更新 UI: 定时任务面板

## Phase 6: 高级功能

- [ ] 浏览器自动化
- [ ] 语音合成
- [ ] 记忆管理

## 实现方式

每个功能通过 OpenClaw Agent 实现：

```javascript
// 示例：读取文件
async function openclawReadFile(path) {
  const result = await window.api.runLocalCommand(
    `openclaw agent --local --session-id "file-op" --message "Read file: ${path}" --json`
  );
  return JSON.parse(result.stdout);
}

// 示例：网络搜索
async function openclawWebSearch(query) {
  const result = await window.api.runLocalCommand(
    `openclaw agent --local --session-id "search" --message "Search the web for: ${query}" --json`
  );
  return JSON.parse(result.stdout);
}
```

## 进度追踪

| Phase | 状态 | 完成度 |
|-------|------|--------|
| Phase 1 | 🔄 进行中 | 20% |
| Phase 2 | ⏳ 待开始 | 0% |
| Phase 3 | ⏳ 待开始 | 0% |
| Phase 4 | ⏳ 待开始 | 0% |
| Phase 5 | ⏳ 待开始 | 0% |
| Phase 6 | ⏳ 待开始 | 0% |
