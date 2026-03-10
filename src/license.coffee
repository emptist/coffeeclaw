# License class for managing user license information

class License
  # Class properties
  @STATUS_ACTIVE: 'active'
  @STATUS_EXPIRED: 'expired'
  @STATUS_PENDING: 'pending'
  @GRACE_PERIOD_DAYS: 7
  
  constructor: (@key = null, @userId = null) ->
    @status = License.STATUS_PENDING
    @createdAt = new Date().toISOString()
    @expiresAt = null
    @lastVerifiedAt = null
    @features = []
    @quota =
      total: 0
      used: 0
      remaining: 0
  
  # Check if license is valid
  isValid: ->
    return false unless @key and @status == License.STATUS_ACTIVE
    return true unless @expiresAt
    new Date() < new Date(@expiresAt)
  
  # Check if license is expired
  isExpired: ->
    return false unless @expiresAt
    new Date() >= new Date(@expiresAt)
  
  # Check if in grace period
  isInGracePeriod: ->
    return false unless @isExpired()
    return false unless @expiresAt
    expiredDate = new Date(@expiresAt)
    now = new Date()
    graceEnd = new Date(expiredDate.getTime() + License.GRACE_PERIOD_DAYS * 24 * 60 * 60 * 1000)
    now < graceEnd
  
  # Activate license
  activate: (features = [], quota = null) ->
    @status = License.STATUS_ACTIVE
    @lastVerifiedAt = new Date().toISOString()
    @features = features
    if quota
      @quota.total = quota
      @quota.remaining = quota
    this
  
  # Deactivate license
  deactivate: (reason = null) ->
    @status = if reason == 'expired' then License.STATUS_EXPIRED else License.STATUS_PENDING
    this
  
  # Update quota
  useQuota: (amount = 1) ->
    @quota.used += amount
    @quota.remaining = Math.max(0, @quota.total - @quota.used)
    this
  
  # Check if has quota remaining
  hasQuota: ->
    return true if @quota.total == 0  # Unlimited
    @quota.remaining > 0
  
  # Check if has feature
  hasFeature: (feature) ->
    @features.includes(feature) or @features.includes('*')
  
  # Set expiration date
  setExpiration: (daysFromNow) ->
    date = new Date()
    date.setDate(date.getDate() + daysFromNow)
    @expiresAt = date.toISOString()
    this
  
  # Get days until expiration
  getDaysUntilExpiration: ->
    return null unless @expiresAt
    now = new Date()
    expires = new Date(@expiresAt)
    diffTime = expires - now
    Math.ceil(diffTime / (1000 * 60 * 60 * 24))
  
  # Get license summary
  getSummary: ->
    {
      status: @status
      isValid: @isValid()
      isExpired: @isExpired()
      isInGracePeriod: @isInGracePeriod()
      daysUntilExpiration: @getDaysUntilExpiration()
      hasQuota: @hasQuota()
      quotaRemaining: @quota.remaining
      features: @features
    }
  
  # Serialization
  toJSON: ->
    {
      __class: 'License'
      key: @key
      userId: @userId
      status: @status
      createdAt: @createdAt
      expiresAt: @expiresAt
      lastVerifiedAt: @lastVerifiedAt
      features: @features
      quota: @quota
    }
  
  @fromJSON: (data) ->
    license = new License(data.key, data.userId)
    license.status = data.status ? License.STATUS_PENDING
    license.createdAt = data.createdAt
    license.expiresAt = data.expiresAt
    license.lastVerifiedAt = data.lastVerifiedAt
    license.features = data.features ? []
    license.quota = data.quota ? { total: 0, used: 0, remaining: 0 }
    license
  
  # Create from legacy format
  @fromLegacy: (data) ->
    license = new License(data.key, data.userId)
    license.status = data.status ? License.STATUS_PENDING
    license.createdAt = data.createdAt ? new Date().toISOString()
    license.expiresAt = data.expiresAt
    license.features = data.features ? []
    if data.quota
      license.quota = data.quota
    license

module.exports = { License }
