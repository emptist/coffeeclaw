# CoffeeClaw 已知问题记录

## 高优先级问题（需要高层次重构解决）

### 1. 模型 ID 格式不一致
**位置**: `src/main.coffee` MODELS 定义 vs `index.html` bot 模型选项

**问题描述**:
- MODELS 中 Zhipu 模型 ID: `glm-4-flash`（不带前缀）
- index.html 中选项值: `glm/glm-4-flash`（带前缀）
- 导致 bot 保存的 model 与 MODELS 中定义不匹配

**影响**:
- 创建 bot 时选择的模型无法正确匹配到 MODELS 配置
- 可能导致 API 调用时使用错误的模型 ID

**解决方案**:
- 引入 Model 类统一管理层级（见 REFACTOR_PLAN.md）
- 所有地方使用 Model 对象，避免字符串格式混乱

### 2. DeepSeek 模型格式不一致
**位置**: `src/main.coffee` MODELS.deepseek

**问题描述**:
- MODELS 中 DeepSeek 模型 ID: `deepseek/deepseek-chat`（带前缀）
- 但 DeepSeek API 实际需要的是 `deepseek-chat`（不带前缀）
- 与 Zhipu 的处理方式不一致

**影响**:
- 调用 DeepSeek API 时可能失败

**解决方案**:
- 使用 Model 子类处理不同 provider 的格式转换
- DeepSeekModel.apiId() 返回不带前缀的 ID

### 3. OpenClaw Agent 模型配置问题
**位置**: `~/.openclaw/openclaw.json` agents.defaults.model.primary

**问题描述**:
- OpenClaw 需要 `provider/model` 格式（如 `glm/glm-4-flash`）
- 但配置中可能保存的是 `glm-4-flash`（不带前缀）
- OpenClaw 默认使用 `anthropic/` 前缀回退，导致 `anthropic/glm-4-flash` 错误

**影响**:
- OpenClaw Agent 无法正常工作
- 报错: "Unknown model: anthropic/glm-4-flash"

**解决方案**:
- syncProvidersToOpenClaw 使用 Model.openClawId() 方法
- 确保总是生成正确的带前缀格式

### 4. loadSettings 截断数据问题（已部分修复）
**位置**: `src/main.coffee` loadSettings 函数

**问题描述**:
- 原代码: `if settings.token and settings.apiKey then return settings else return {}`
- 导致缺少 token/apiKey 时返回空对象，丢失 providers 等其他配置
- 已修复为总是返回完整 settings 对象

**状态**: ✅ 已修复

### 5. createDefaultConfig 覆盖 providers 问题（已修复）
**位置**: `src/main.coffee` createDefaultConfig 函数

**问题描述**:
- 使用 loadSettings() 返回的对象保存，可能截断 providers
- 导致 `providers.zhipu.apiKey` 只有一半（缺少后缀）
- 已修复为 loadSettings 返回完整对象

**状态**: ✅ 已修复

### 6. token 不同步问题（已修复）
**位置**: `src/main.coffee` syncProvidersToOpenClaw 函数

**问题描述**:
- CoffeeClaw 和 OpenClaw 使用不同的 token
- 导致 "令牌已过期或验证不正确" 错误
- 已添加 token 同步逻辑

**状态**: ✅ 已修复

## 当前代码变更审查

### src/main.coffee 变更

#### ✅ 正确变更:
1. **loadSettings 修复** (第 53-58 行)
   - 总是返回完整 settings 对象
   - 避免数据截断

2. **createDefaultConfig OpenClaw 模型格式** (第 679, 681 行)
   - `glm/GLM-4-Flash` → `glm/glm-4-flash`
   - 统一使用小写格式

3. **syncProvidersToOpenClaw token 同步** (第 1404-1523 行)
   - 添加 token 参数
   - 同步 token 到 OpenClaw 配置

#### ⚠️ 可能有问题:
1. **DeepSeek 模型 ID 格式** (第 856-861 行)
   - 改为 `deepseek/deepseek-chat`（带前缀）
   - 需要确认 DeepSeek API 是否接受这种格式
   - **风险**: 如果 DeepSeek API 需要 `deepseek-chat`，调用会失败

### index.html 变更

#### ⚠️ 有问题:
1. **Zhipu 模型选项值** (第 1202-1204 行)
   - 改为 `glm/glm-4-flash`（带前缀）
   - 但 MODELS 中定义的是 `glm-4-flash`（不带前缀）
   - **风险**: bot 保存的 model 无法在 MODELS 中找到匹配

#### ✅ 正确变更:
1. **DeepSeek 模型选项** (第 1205-1206 行)
   - 添加 `deepseek/deepseek-chat` 和 `deepseek/deepseek-coder`
   - 与 MODELS 定义一致

2. **provider 标签** (第 1146 行)
   - "DeepSeek" → "DeepSeek (Free)"
   - 信息更新

3. **保存 activeProvider** (第 2268-2270 行)
   - 切换 provider 时自动保存
   - 逻辑正确

## 建议行动

### 立即行动:
1. 修复 index.html 中 Zhipu 模型选项值，与 MODELS 保持一致
2. 测试 DeepSeek 模型调用，确认带前缀格式是否可用

### 短期行动:
1. 按照 REFACTOR_PLAN.md 实施 Model 类重构
2. 统一所有模型 ID 处理逻辑

### 长期行动:
1. 使用 LowDB 替代手动 JSON 文件操作
2. 添加自动化测试验证模型解析
