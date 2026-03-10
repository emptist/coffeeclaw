# Feishu (Lark) configuration class
# Manages Feishu bot integration settings

class FeishuConfig
  # Class properties - default values
  @DEFAULT_BOT_NAME = 'CoffeeClaw'
  @DEFAULT_DM_POLICY = 'pairing'
  @DEFAULT_GROUP_POLICY = 'open'
  @SUPPORTED_POLICIES = ['open', 'pairing', 'disabled']
  
  constructor: (options = {}) ->
    # Instance properties
    @enabled = options.enabled ? false
    @appId = options.appId ? ''
    @appSecret = options.appSecret ? ''
    @botName = options.botName ? FeishuConfig.DEFAULT_BOT_NAME
    @dmPolicy = options.dmPolicy ? FeishuConfig.DEFAULT_DM_POLICY
    @groupPolicy = options.groupPolicy ? FeishuConfig.DEFAULT_GROUP_POLICY
    
    # Internal tracking
    @_lastConnectedAt = null
    @_connectionStatus = 'disconnected'
  
  # Validation methods
  isValid: ->
    @enabled and @appId?.length > 0 and @appSecret?.length > 0
  
  validate: ->
    errors = []
    
    if @enabled
      if !@appId or @appId.length == 0
        errors.push("App ID is required when Feishu is enabled")
      if !@appSecret or @appSecret.length == 0
        errors.push("App Secret is required when Feishu is enabled")
    
    unless @dmPolicy in FeishuConfig.SUPPORTED_POLICIES
      errors.push("Invalid DM policy: #{@dmPolicy}")
    
    unless @groupPolicy in FeishuConfig.SUPPORTED_POLICIES
      errors.push("Invalid group policy: #{@groupPolicy}")
    
    if errors.length > 0
      throw new Error(errors.join(', '))
    
    true
  
  # Policy check methods
  canRespondToDM: ->
    return false unless @enabled
    @dmPolicy != 'disabled'
  
  canRespondToGroup: ->
    return false unless @enabled
    @groupPolicy != 'disabled'
  
  needsPairingForDM: ->
    @dmPolicy == 'pairing'
  
  needsPairingForGroup: ->
    @groupPolicy == 'pairing'
  
  # Update methods
  update: (changes) ->
    for key, value of changes
      switch key
        when 'enabled'
          @enabled = value
        when 'appId'
          @appId = value
        when 'appSecret'
          @appSecret = value
        when 'botName'
          @botName = value ? FeishuConfig.DEFAULT_BOT_NAME
        when 'dmPolicy'
          if value in FeishuConfig.SUPPORTED_POLICIES
            @dmPolicy = value
          else
            throw new Error("Invalid DM policy: #{value}")
        when 'groupPolicy'
          if value in FeishuConfig.SUPPORTED_POLICIES
            @groupPolicy = value
          else
            throw new Error("Invalid group policy: #{value}")
    
    this
  
  # Connection tracking
  markConnected: ->
    @_lastConnectedAt = new Date().toISOString()
    @_connectionStatus = 'connected'
  
  markDisconnected: ->
    @_connectionStatus = 'disconnected'
  
  getConnectionStatus: ->
    {
      status: @_connectionStatus
      lastConnectedAt: @_lastConnectedAt
    }
  
  # Serialization
  toJSON: ->
    {
      __class: 'FeishuConfig'
      enabled: @enabled
      appId: @appId
      appSecret: @appSecret
      botName: @botName
      dmPolicy: @dmPolicy
      groupPolicy: @groupPolicy
      # Note: internal properties (_lastConnectedAt, _connectionStatus) are not saved
    }
  
  @fromJSON: (data) ->
    config = new FeishuConfig(
      enabled: data.enabled
      appId: data.appId
      appSecret: data.appSecret
      botName: data.botName
      dmPolicy: data.dmPolicy
      groupPolicy: data.groupPolicy
    )
    config
  
  # Create from legacy format (for migration)
  @fromLegacy: (data) ->
    new FeishuConfig(
      enabled: data.enabled ? false
      appId: data.appId ? ''
      appSecret: data.appSecret ? ''
      botName: data.botName ? FeishuConfig.DEFAULT_BOT_NAME
      dmPolicy: data.dmPolicy ? FeishuConfig.DEFAULT_DM_POLICY
      groupPolicy: data.groupPolicy ? FeishuConfig.DEFAULT_GROUP_POLICY
    )

module.exports = { FeishuConfig }
