# CoffeeClaw Code Review

## Overview
CoffeeClaw is an Electron-based desktop AI assistant that integrates with OpenClaw gateway and supports Feishu (飞书) integration. The codebase consists of:
- `src/main.coffee` - Main process (Electron)
- `src/preload.coffee` - Preload script (IPC bridge)
- `index.html` - Frontend (vanilla JS + inline styles)

---

## Strengths

### 1. Clean Architecture
- Proper separation between main process, preload, and renderer
- Context isolation enabled (`contextIsolation: true`)
- IPC-based communication via `contextBridge.exposeInMainWorld`

### 2. Multi-Bot Support
- Well-implemented bot management system (create, update, delete, switch)
- Sessions are bot-specific
- System prompts per bot

### 3. Feishu Integration
- Comprehensive Feishu setup flow with permissions list
- Pairing approval workflow
- Configuration syncing between settings and OpenClaw config

### 4. Good UX Features
- Multi-language support (EN, 中文, Espo)
- Session management with sidebar
- Setup wizard with progress tracking

---

## Issues & Recommendations

### Security (High Priority)

**1. Sensitive Data in Plain Text** (`main.coffee:301-304`, `main.coffee:792-807`)
- API keys stored in JSON config files without encryption
- App secrets written directly to filesystem
```coffeescript
# Current (unsafe)
config.env.ZHIPU_API_KEY = key
settings.feishu = { appSecret: appSecret, ... }
```
- **Recommendation**: Use `electron-store` with encryption or system keychain

**2. No Input Validation** (`main.coffee:855-881`)
- `saveFeishuConfig` accepts any input without validation
- App ID/App Secret not validated before saving
```coffeescript
# Add validation
return false unless appId.match(/^cli_[a-z0-9]+$/)
return false unless appSecret.length >= 16
```

**3. eval() Risk** (`main.coffee:92`)
- Session title uses `substring` which is safe, but similar patterns elsewhere could be dangerous
- Ensure no `eval` or `Function` with user content

---

### Code Quality (Medium Priority)

**4. Duplicate Code** 
- `save-feishu-config` (line 855) and `setup-feishu` (line 963) have nearly identical logic
- Extract to shared function

**5. Magic Numbers** (`main.coffee:23-24`)
```coffeescript
MAX_HISTORY = 100
MAX_SESSIONS = 50
```
- Move to config section at top of file

**6. Inconsistent Error Handling**
- Some functions return `null`, others throw, others return error objects
- Standardize: prefer throwing errors for exceptional cases

**7. Unused Variables** (`main.coffee:921`)
```coffeescript
catch err
  pass  # Should at least log
```
- At minimum: `console.error('Pairing check error:', err)`

---

### Functionality (Medium Priority)

**8. No Retry Logic for API Calls** (`main.coffee:532-552`)
- `callAPI` has no retry on transient failures
- Consider adding 1-2 retries with exponential backoff

**9. Race Conditions Possible**
- `loadSessions` → modify → `saveSessions` without locking
- Concurrent IPC calls could cause data loss
```coffeescript
# Current (race-prone)
session = getSession sessionId
# ... modify ...
saveSession sessionId, session
```
- Consider using a mutex or in-memory cache with periodic writes

**10. Hardcoded Model List** (`main.coffee:464-490`)
- Model list is hardcoded, not fetched dynamically
- Should fetch from OpenClaw or allow custom models

---

### Frontend Issues (Low Priority)

**11. XSS in Session Titles** (`index.html:906`)
```javascript
<div class="title">${session.title || ...}</div>
```
- Session titles rendered without sanitization
- Use `textContent` or sanitize

**12. No Input Sanitization** (`index.html:867`)
- User messages sent directly to API without sanitization

**13. Inline Styles**
- ~400 lines of CSS in `<style>` tag
- Consider separating to external CSS file for maintainability

---

### Configuration/Deployment (Low Priority)

**14. Secrets in .secrete/**
- Files listed in `.gitignore` but directory structure is confusing
- Document expected files in README

**15. Build Excludes** (`package.json:35-42`)
```json
"files": ["**/*", "!**/*.coffee"]
```
- Good, but `.secrete` should also be excluded from builds (currently only from git)

---

## Summary

| Category | Count |
|----------|-------|
| High Priority | 3 |
| Medium Priority | 4 |
| Low Priority | 5 |

**Overall**: Solid implementation for a personal AI assistant. Main concerns are around security of stored credentials and lack of input validation. The Feishu integration is well thought out.

---

## Suggested Priority Fixes

1. **Encrypt stored credentials** - Use electron-store with encryption
2. **Validate Feishu config inputs** - Add regex validation for app ID
3. **Sanitize user content** - Prevent XSS in session titles
4. **Extract duplicate Feishu code** - DRY principle
5. **Add session locking** - Prevent race conditions

---

## Financial/Subscription Feature (NEW)

### Implementation Overview
Added subscription/quota system with "pay what you can" model:

**Files Created/Modified:**
- `src/payment-server.coffee` - Payment backend (Stripe + Alipay/WeChat Pay)
- `src/main.coffee` - Added quota IPC handlers
- `src/preload.coffee` - Exposed quota APIs
- `index.html` - Quota display + payment modal

### Pricing
- **Global**: $15/month (~1000 messages)
- **China (¥18/月)**: ~200 messages (lower due to lower purchasing power)
- **Free tier**: 50 messages (global) / 100 messages (China)

### Payment Providers
- Stripe handles: Credit cards, Alipay, WeChat Pay
- Single integration for global + China coverage

### Usage Flow
1. App generates device ID on first run
2. User gets free quota automatically
3. Quota displayed in header (green >0, red ≤0)
4. User can subscribe anytime via quota button
5. Payment via Stripe checkout (opens in browser)

### Security Considerations
- Device ID is hashed - not traceable to physical machine
- Payment verification handled server-side
- No raw credit card data touches the app

### Missing / Future Improvements
- Webhook for automatic payment verification (currently polls)
- Refund handling
- Subscription management portal
- Invoice generation
- Email receipts
- Stripe webhook signature verification

### To Enable Payments
```bash
# Set Stripe secret key before running payment server
export STRIPE_SECRET_KEY=sk_live_xxxxx
npm run payment-server
```

### Known Limitations
- Payment server runs separately from main app
- User needs to run both: `npm start` + `npm run payment-server`
- Consider bundling payment server into main app or using separate hosting
