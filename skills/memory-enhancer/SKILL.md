# memory-enhancer

## Description

记忆增强器 - 智能管理和增强 OpenClaw/CoffeeClaw 的记忆系统，提供自动标签分类、关键信息提取、语义搜索、记忆可视化等功能，让记忆系统发挥更大价值。

## When to Use

当用户需要以下记忆相关操作时激活此技能：
- 搜索历史记忆
- 整理和分类记忆
- 提取关键信息
- 生成记忆摘要
- 关联相关记忆
- 清理过期记忆

## Tools

此技能需要使用以下工具：
- `Read` - 读取记忆文件
- `Write` - 创建增强后的记忆
- `SearchReplace` - 修改记忆内容
- `Glob` - 查找记忆文件
- `Grep` - 搜索记忆内容
- `SearchCodebase` - 搜索代码库

## Memory System

### 记忆文件位置
- OpenClaw全局记忆：`~/.openclaw/.openclaw/`
- CoffeeClaw项目记忆：`~/.openclaw/workspace/coffeeclaw/.openclaw/`

### 记忆文件类型
- `CONTEXT.md` - 当前上下文
- `DECISIONS.md` - 决策记录
- `MEMORY.md` - 项目记忆
- `PROGRESS.md` - 进度追踪
- `PROJECT.md` - 项目概述
- `TODO.md` - 待办事项

### 会话历史
- 位置：`~/.openclaw/agents/main/sessions/`
- 格式：JSONL (每行一个JSON事件)
- 索引：`sessions.json`

## Features

### 1. 自动标签分类

自动为记忆内容添加标签：
- **技术标签**: #coding #architecture #bugfix #refactor
- **业务标签**: #feature #marketing #business #revenue
- **类型标签**: #decision #lesson #idea #question
- **优先级标签**: #urgent #important #low-priority

### 2. 关键信息提取

从会话和记忆中提取：
- **决策点** - 重要的技术或业务决策
- **待办事项** - 需要完成的任务
- **关键信息** - 重要的项目信息
- **问题记录** - 遇到的问题和解决方案
- **经验教训** - 总结的经验

### 3. 语义搜索

支持多种搜索方式：
- **关键词搜索** - 精确匹配关键词
- **语义搜索** - 理解意图的模糊搜索
- **时间搜索** - 按时间范围搜索
- **标签搜索** - 按标签筛选
- **组合搜索** - 多条件组合

### 4. 记忆关联

自动发现记忆间的关联：
- **相关决策** - 关联相关的决策记录
- **依赖关系** - 识别任务间的依赖
- **时间线** - 按时间组织记忆
- **主题聚类** - 按主题分组

### 5. 记忆摘要

生成记忆的智能摘要：
- **每日摘要** - 一天的活动总结
- **每周回顾** - 周度进展总结
- **项目摘要** - 项目整体概况
- **决策摘要** - 关键决策汇总

## Workflow

1. **收集记忆** - 读取所有记忆文件和会话
2. **分析内容** - 提取关键信息和标签
3. **建立关联** - 发现记忆间的联系
4. **生成摘要** - 创建记忆摘要
5. **更新索引** - 更新搜索索引

## Commands

### 搜索记忆
```
搜索记忆 "MemorySync实现"
搜索记忆 标签:#coding 时间:本周
搜索记忆 类型:decision 关键词:架构
```

### 提取待办
```
提取待办事项 从会话:main
提取待办事项 从记忆:所有
```

### 生成摘要
```
生成今日摘要
生成本周回顾
生成项目摘要
```

### 添加标签
```
自动标签分类
为记忆添加标签 #important
```

### 关联记忆
```
查找相关记忆 "OpenClaw集成"
建立记忆关联 记忆A 记忆B
```

### 清理记忆
```
清理过期记忆 保留:30天
归档已完成项目
```

## Search Syntax

### 基础搜索
```
关键词
```

### 高级搜索
```
关键词 标签:#coding 时间:2026-03 类型:decision
```

### 搜索修饰符
- `标签:#xxx` - 按标签搜索
- `时间:xxx` - 按时间搜索 (今天/本周/本月/YYYY-MM)
- `类型:xxx` - 按类型搜索 (decision/lesson/todo)
- `文件:xxx` - 在指定文件中搜索
- `作者:xxx` - 按作者搜索

## Memory Index

### 索引结构
```json
{
  "indexVersion": "1.0",
  "lastUpdated": "2026-03-13T10:00:00Z",
  "entries": [
    {
      "id": "uuid",
      "source": "MEMORY.md",
      "type": "decision",
      "content": "...",
      "tags": ["#architecture", "#important"],
      "timestamp": "2026-03-10T15:30:00Z",
      "related": ["uuid1", "uuid2"]
    }
  ]
}
```

### 索引更新策略
- **实时更新** - 记忆文件变化时立即更新
- **定时更新** - 每小时完整重建索引
- **手动更新** - 用户触发时更新

## Best Practices

1. **定期整理** - 每周整理一次记忆
2. **及时标签** - 为重要记忆添加标签
3. **提取待办** - 定期从会话中提取待办事项
4. **清理过期** - 定期清理过期的临时记忆
5. **建立关联** - 主动建立相关记忆的关联

## Data Location

增强器数据存储在：
- `~/.openclaw/workspace/coffeeclaw/data/memory-enhancer/`
- `memory-index.json` - 记忆索引
- `tags.json` - 标签定义
- `relations.json` - 记忆关联
- `summaries/` - 生成的摘要

## Integration with OpenClaw

### 读取会话历史
```coffee
readSessions: ->
  sessionsDir = path.join(@openclawDir, 'agents', 'main', 'sessions')
  # 读取 sessions.json 获取索引
  # 读取 *.jsonl 文件获取详细历史
```

### 更新记忆文件
```coffee
updateMemory: (filename, content) ->
  # 同时更新 OpenClaw 和 CoffeeClaw 的记忆文件
  # 触发同步机制
```

## Examples

### 示例1：搜索相关决策

用户：帮我找一下关于MemorySync实现的所有决策记录

执行：
1. 搜索关键词 "MemorySync"
2. 筛选类型为 decision 的结果
3. 按时间排序展示

### 示例2：提取待办事项

用户：从最近的会话中提取所有待办事项

执行：
1. 读取最近7天的会话
2. 识别任务相关的消息
3. 提取具体的待办事项
4. 更新 TODO.md

### 示例3：生成项目回顾

用户：生成CoffeeClaw项目的月度回顾

执行：
1. 读取本月所有记忆文件
2. 提取关键进展和决策
3. 统计完成的任务
4. 生成月度回顾报告

### 示例4：自动标签分类

用户：帮我把所有记忆自动分类打标签

执行：
1. 读取所有记忆内容
2. 分析内容主题
3. 自动添加合适的标签
4. 更新记忆文件
