# Trae + OpenClaw 协作机制

## 协作模式

**Trae (现代唐三藏)**: 设计、分析、决策、审查
**OpenClaw (数字孙悟空)**: 执行、操作、实现、反馈

## 权限对比

| 能力 | Trae | OpenClaw |
|------|------|----------|
| 执行命令 | 需要 approval | 直接执行 |
| 修改文件 | 通过工具 | 直接读写 |
| 访问网络 | 受限 | web_fetch/browser |
| GitHub 操作 | 受限 | gh 命令 |
| 飞书集成 | 无 | feishu-* 技能 |
| 定时任务 | 无 | cron 工具 |

## 协作流程

```
1. Trae 分析需求
2. Trae 设计方案
3. OpenClaw 执行实现
4. OpenClaw 返回结果
5. Trae 审查完善
6. 共同提交代码
```

## 代理执行接口

### 命令执行
```
Trae: "孙悟空，执行命令: [command]"
OpenClaw: 执行并返回结果
```

### 文件操作
```
Trae: "孙悟空，修改文件: [path] [changes]"
OpenClaw: 修改并确认
```

### API 调用
```
Trae: "孙悟空，调用 API: [url] [method] [data]"
OpenClaw: 调用并返回响应
```

## 当前项目

- 项目: CoffeeClaw
- 路径: /Users/jk/gits/hub/tools_ai/coffeeclaw/
- 仓库: emptist/coffeeclaw

## 已完成功能

- [x] Session export button
- [x] Keyboard shortcuts
- [x] Run local command button
- [x] OpenClaw Tools toolbox (8 tools)
- [x] GitHub Issue 创建

## 待完成功能

- [ ] 飞书消息真正集成
- [ ] GitHub Actions CI/CD
- [ ] 代码高亮
- [ ] 更多工具集成
