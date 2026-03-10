# Future Refactoring Ideas

This document contains refactoring ideas for future improvements.
These are not urgent but would improve code organization and maintainability.

## 1. Move IPC Handler Logic to Classes

**Current Issue:**
IPC handlers in main.coffee contain business logic that should be in classes.

**Example - activate-license handler (line 1643):**
```coffee
ipcMain.handle 'activate-license', (event, plan, paymentInfo) ->
  license = loadLicense()
  unless license
    license = initLicense()
  
  license.paid = true
  license.plan = plan
  license.activatedAt = new Date().toISOString()
  
  if plan == 'lifetime'
    license.showIndicator = false
  else if plan == 'yearly'
    license.balance = (license.balance or 0) + 12
  else if plan == 'monthly'
    license.balance = (license.balance or 0) + 1
  
  license.paymentInfo = paymentInfo
  saveLicense license
  getLicenseStatus()
```

**Proposed Change:**
Move this logic to License class:
```coffee
class License
  activate: (plan, paymentInfo) ->
    @paid = true
    @plan = plan
    @activatedAt = new Date().toISOString()
    @paymentInfo = paymentInfo
    
    switch plan
      when 'lifetime' then @balance = 0
      when 'yearly' then @balance += 12
      when 'monthly' then @balance += 1
    
    this
  
  addPayment: (amount, currency, method) ->
    # Validation and logic here
    @balance += amount
    @paid = true
    # Check for lifetime threshold
    lifetimeThreshold = if currency == 'cny' then 216 else 36
    if amount >= lifetimeThreshold
      @plan = 'lifetime'
    this
```

Then IPC handler becomes:
```coffee
ipcMain.handle 'activate-license', (event, plan, paymentInfo) ->
  license = loadLicense()
  license.activate(plan, paymentInfo)
  saveLicense()
  license.getStatus()
```

## 2. Consolidate Payment Logic

**Current Issue:**
Payment logic is scattered across multiple handlers and functions.

**Files to Review:**
- `activate-license` handler
- `add-payment` handler  
- `getLicenseStatus` function

**Proposed Change:**
Create a PaymentManager class:
```coffee
class PaymentManager
  @LIFETIME_THRESHOLD_USD = 36
  @LIFETIME_THRESHOLD_CNY = 216
  
  constructor: (@license) ->
  
  processPayment: (amount, currency, method) ->
    # All payment logic here
    
  calculateBalance: (plan) ->
    # Plan to balance conversion
    
  shouldUpgradeToLifetime: (totalPaid) ->
    # Check threshold
```

## 3. Simplify IPC Handler Registration

**Current Issue:**
IPC handlers are registered throughout main.coffee, making it hard to track.

**Proposed Change:**
Group all IPC handlers together or use a registration pattern:
```coffee
class IPCHandlers
  @register: ->
    ipcMain.handle 'activate-license', @activateLicense
    ipcMain.handle 'add-payment', @addPayment
    # ... etc
  
  @activateLicense: (event, plan, paymentInfo) ->
    # Handler implementation
```

## 4. Extract Configuration Constants

**Current Issue:**
Constants like prices, thresholds are scattered in code.

**Proposed Change:**
Create a Config class:
```coffee
class Config
  @LICENSE_PRICES =
    yearly_usd: 12
    yearly_cny: 72
    lifetime_usd: 36
    lifetime_cny: 216
    monthly_usd: 1
    monthly_cny: 6
  
  @LIFETIME_THRESHOLD =
    usd: 36
    cny: 216
  
  @INITIAL_BALANCE = 1
  @MAX_HISTORY = 100
  @MAX_SESSIONS = 50
```

## 5. Improve Error Handling

**Current Issue:**
Many functions return null or simple objects on error.

**Proposed Change:**
Use a Result pattern:
```coffee
class Result
  constructor: (@success, @data, @error) ->
  
  @ok: (data) -> new Result(true, data, null)
  @err: (error) -> new Result(false, null, error)

# Usage
activateLicense = (plan) ->
  unless plan in ['monthly', 'yearly', 'lifetime']
    return Result.err('Invalid plan')
  # ... process ...
  Result.ok(license)
```

## 6. Add Logging Infrastructure

**Current Issue:**
Using console.log/error inconsistently.

**Proposed Change:**
Create a Logger class:
```coffee
class Logger
  @debug: (msg) -> console.log "[DEBUG] #{msg}" if @isDebug
  @info: (msg) -> console.log "[INFO] #{msg}"
  @warn: (msg) -> console.warn "[WARN] #{msg}"
  @error: (msg, err) -> console.error "[ERROR] #{msg}", err
```

## Priority Assessment

**High Priority (Do Soon):**
1. Move IPC logic to classes - improves testability
2. Consolidate payment logic - reduces bugs

**Medium Priority (Do Later):**
3. Simplify IPC registration - improves organization
4. Extract configuration - improves maintainability

**Low Priority (Nice to Have):**
5. Improve error handling - improves robustness
6. Add logging - improves debugging

## Notes

- These changes should be done one at a time
- Each change should have its own commit
- Test thoroughly after each change
- Consider backward compatibility
