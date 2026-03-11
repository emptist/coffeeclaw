# Bot Settings Modal Fix

## Problem

When editing a bot, the model selector was always empty.

## Root Cause

The `bot.model` property is a **Model instance object**, but the selector expects a **string ID**.

```javascript
// Before (incorrect):
document.getElementById('botModelSelect').value = bot.model;
// bot.model is an object like: { id: 'glm-4-flash', provider: 'zhipu', ... }

// After (correct):
document.getElementById('botModelSelect').value = bot.model?.rawId ? bot.model.rawId() : bot.model;
// Extracts the raw ID string: 'glm-4-flash'
```

## Solution

Modified [index.html:2432](file:///Users/jk/gits/hub/tools_ai/coffeeclaw/index.html#L2432) to extract the raw ID from the Model instance:

```javascript
document.getElementById('botModelSelect').value = bot.model?.rawId ? bot.model.rawId() : bot.model;
```

This:
1. Checks if `bot.model` has a `rawId()` method (Model instance)
2. If yes, calls `rawId()` to get the string ID
3. If no, uses the value as-is (backward compatibility)

## Testing

After restart:
1. Click edit button on any bot
2. Model selector should show the correct model selected
3. Change model and save
4. Open again - should still show the selected model

## Related

- [src/bot.coffee](file:///Users/jk/gits/hub/tools_ai/coffeeclaw/src/bot.coffee) - Bot class with Model instance
- [src/model.coffee](file:///Users/jk/gits/hub/tools_ai/coffeeclaw/src/model.coffee) - Model class with `rawId()` method
