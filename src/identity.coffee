# Identity class for managing machine identity and hardware fingerprinting
# Used for license verification and device tracking

os = require 'os'
crypto = require 'crypto'

class Identity
  # Class properties
  @VERSION = 1
  
  constructor: ->
    @version = Identity.VERSION
    @machineId = @generateMachineId()
    @createdAt = new Date().toISOString()
    @lastUpdatedAt = @createdAt
    @hardwareInfo = @collectHardwareInfo()
  
  # Generate a unique machine ID based on hardware
  generateMachineId: ->
    # Collect various hardware identifiers
    identifiers = []
    
    # CPU info
    try
      cpus = os.cpus()
      if cpus and cpus.length > 0
        identifiers.push cpus[0].model
        identifiers.push cpus.length.toString()
    catch e
      console.error 'Failed to get CPU info:', e
    
    # Network interfaces (MAC addresses)
    try
      interfaces = os.networkInterfaces()
      for name, addrs of interfaces
        for addr in addrs
          # Use physical MAC addresses only (not internal/virtual)
          if addr.mac and addr.mac != '00:00:00:00:00:00'
            identifiers.push addr.mac
    catch e
      console.error 'Failed to get network interfaces:', e
    
    # Platform and hostname
    identifiers.push os.platform()
    identifiers.push os.arch()
    try
      identifiers.push os.hostname()
    catch e
      console.error 'Failed to get hostname:', e
    
    # Generate hash from collected identifiers
    hash = crypto.createHash('sha256')
    hash.update(identifiers.join('|'))
    hash.digest('hex').substring(0, 32)
  
  # Collect hardware information (for reference, not part of ID)
  collectHardwareInfo: ->
    {
      platform: os.platform()
      arch: os.arch()
      cpus: os.cpus()?.length ? 0
      totalMemory: os.totalmem()
      hostname: try os.hostname() catch e then 'unknown'
    }
  
  # Verify if current hardware matches stored identity
  verify: ->
    currentId = @generateMachineId()
    currentId == @machineId
  
  # Update identity (if hardware changed significantly)
  update: ->
    @hardwareInfo = @collectHardwareInfo()
    @lastUpdatedAt = new Date().toISOString()
    this
  
  # Regenerate machine ID (e.g., after major hardware change)
  regenerate: ->
    @machineId = @generateMachineId()
    @update()
    this
  
  # Get short ID for display
  getShortId: ->
    @machineId.substring(0, 8) + '...'
  
  # Serialization
  toJSON: ->
    {
      __class: 'Identity'
      version: @version
      machineId: @machineId
      createdAt: @createdAt
      lastUpdatedAt: @lastUpdatedAt
      hardwareInfo: @hardwareInfo
    }
  
  @fromJSON: (data) ->
    identity = new Identity()
    identity.version = data.version ? Identity.VERSION
    identity.machineId = data.machineId
    identity.createdAt = data.createdAt
    identity.lastUpdatedAt = data.lastUpdatedAt ? data.createdAt
    identity.hardwareInfo = data.hardwareInfo ? {}
    identity
  
  # Create from string (legacy format)
  @fromString: (str) ->
    identity = new Identity()
    identity.machineId = str
    identity

module.exports = { Identity }
