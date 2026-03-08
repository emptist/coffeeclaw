# OpenClaw 飞书配置指南

## 飞书应用权限配置

OpenClawBot

### 批量导入权限

在飞书开发者后台，进入应用 → **权限管理** → 点击 **批量导入** 按钮，粘贴以下 JSON：

```json
{
  "scopes": {
    "tenant": [
      "aily:file:read",
      "aily:file:write",
      "application:application.app_message_stats.overview:readonly",
      "application:application:self_manage",
      "application:bot.menu:write",
      "cardkit:card:write",
      "contact:user.employee_id:readonly",
      "contact:contact.base:readonly",
      "contact:contact:access_as_app",
      "contact:contact:readonly",
      "contact:contact:readonly_as_app",
      "corehr:file:download",
      "docs:document.content:read",
      "event:ip_list",
      "im:chat",
      "im:chat.access_event.bot_p2p_chat:read",
      "im:chat.members:bot_access",
      "im:message",
      "im:message.group_at_msg:readonly",
      "im:message.group_msg",
      "im:message.p2p_msg:readonly",
      "im:message:readonly",
      "im:message:send_as_bot",
      "im:resource",
      "sheets:spreadsheet",
      "wiki:wiki:readonly"
    ],
    "user": [
      "aily:file:read",
      "aily:file:write",
      "im:chat.access_event.bot_p2p_chat:read"
    ]
  }
}
```

## 权限说明

### 消息相关权限
- `im:message` - 发送消息
- `im:message:readonly` - 读取消息
- `im:message.p2p_msg:readonly` - 读取私聊消息
- `im:message.group_at_msg:readonly` - 读取群聊@消息
- `im:chat` - 管理群组

### 文件相关权限
- `aily:file:read` - 读取文件
- `aily:file:write` - 写入文件

### 文档相关权限
- `docs:document.content:read` - 读取文档内容
- `sheets:spreadsheet` - 访问电子表格
- `wiki:wiki:readonly` - 访问知识库

### 其他权限
- `contact:user.employee_id:readonly` - 读取用户信息
- `cardkit:card:write` - 发送卡片消息

## 后续配置步骤

### 1. 启用机器人能力
- 应用能力 → 机器人 → 开启

### 2. 配置事件订阅
- 选择"使用长连接接收事件"
- 添加事件：`im.message.receive_v1`

### 3. 发布应用
- 版本管理与发布 → 创建版本 → 发布

## 注意事项

⚠️ **重要**：在配置事件订阅前，确保：
- 已运行 `openclaw channels add` 添加了飞书渠道
- 网关处于启动状态（`openclaw gateway status`）

## 参考链接

- 飞书开放平台：https://open.feishu.cn/
- OpenClaw 官方文档：https://docs.openclaw.ai/
