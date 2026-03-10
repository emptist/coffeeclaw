# Backup Manager class for handling data backup and restore
# Manages backup creation, listing, and restoration

fs = require 'fs'
path = require 'path'

class BackupManager
  # Class properties
  @DEFAULT_BACKUP_DIR: path.join process.env.HOME, '.coffeeclaw', 'backups'
  @MAX_BACKUPS: 20
  @BACKUP_VERSION = 1
  
  constructor: (backupDir = null) ->
    @backupDir = backupDir ? BackupManager.DEFAULT_BACKUP_DIR
    @ensureBackupDir()
  
  # Ensure backup directory exists
  ensureBackupDir: ->
    unless fs.existsSync(@backupDir)
      fs.mkdirSync(@backupDir, recursive: true)
  
  # Generate backup filename
  generateBackupFilename: ->
    timestamp = new Date().toISOString().replace(/[:.]/g, '-')
    "backup-#{timestamp}.json"
  
  # Create a backup
  createBackup: (data) ->
    try
      @ensureBackupDir()
      
      # Clean up old backups first
      @cleanupOldBackups()
      
      # Prepare backup data
      backupData =
        __class: 'Backup'
        version: BackupManager.BACKUP_VERSION
        createdAt: new Date().toISOString()
        data: data
      
      # Write backup file
      filename = @generateBackupFilename()
      filepath = path.join(@backupDir, filename)
      fs.writeFileSync(filepath, JSON.stringify(backupData, null, 2))
      
      {
        success: true
        filename: filename
        filepath: filepath
        timestamp: backupData.createdAt
      }
    catch e
      console.error 'Failed to create backup:', e
      {
        success: false
        error: e.message
      }
  
  # List all backups
  listBackups: ->
    try
      @ensureBackupDir()
      
      files = fs.readdirSync(@backupDir)
        .filter (f) -> f.startsWith('backup-') and f.endsWith('.json')
        .map (f) =>
          filepath = path.join(@backupDir, f)
          stat = fs.statSync(filepath)
          {
            filename: f
            filepath: filepath
            createdAt: stat.mtime.toISOString()
            size: stat.size
          }
        .sort (a, b) -> new Date(b.createdAt) - new Date(a.createdAt)
      
      files
    catch e
      console.error 'Failed to list backups:', e
      []
  
  # Get latest backup
  getLatestBackup: ->
    backups = @listBackups()
    return null if backups.length == 0
    backups[0]
  
  # Load backup data
  loadBackup: (filename) ->
    try
      filepath = if path.isAbsolute(filename)
        filename
      else
        path.join(@backupDir, filename)
      
      unless fs.existsSync(filepath)
        return { success: false, error: 'Backup file not found' }
      
      data = JSON.parse(fs.readFileSync(filepath, 'utf8'))
      
      # Validate backup format
      unless data.__class == 'Backup' or data.data
        return { success: false, error: 'Invalid backup format' }
      
      {
        success: true
        data: data.data ? data
        metadata:
          version: data.version
          createdAt: data.createdAt
      }
    catch e
      console.error 'Failed to load backup:', e
      { success: false, error: e.message }
  
  # Restore from backup
  restoreBackup: (filename, restoreHandler) ->
    result = @loadBackup(filename)
    return result unless result.success
    
    try
      # Call restore handler with data
      if restoreHandler
        restoreResult = restoreHandler(result.data)
        return restoreResult if restoreResult?.success == false
      
      { success: true, data: result.data }
    catch e
      console.error 'Failed to restore backup:', e
      { success: false, error: e.message }
  
  # Delete a backup
  deleteBackup: (filename) ->
    try
      filepath = path.join(@backupDir, filename)
      
      unless fs.existsSync(filepath)
        return { success: false, error: 'Backup file not found' }
      
      fs.unlinkSync(filepath)
      { success: true }
    catch e
      console.error 'Failed to delete backup:', e
      { success: false, error: e.message }
  
  # Clean up old backups
  cleanupOldBackups: (keep = BackupManager.MAX_BACKUPS) ->
    try
      backups = @listBackups()
      
      if backups.length > keep
        toDelete = backups.slice(keep)
        for backup in toDelete
          fs.unlinkSync(backup.filepath)
          console.log "Cleaned up old backup: #{backup.filename}"
        
        { success: true, deleted: toDelete.length }
      else
        { success: true, deleted: 0 }
    catch e
      console.error 'Failed to cleanup backups:', e
      { success: false, error: e.message }
  
  # Get backup statistics
  getStats: ->
    backups = @listBackups()
    totalSize = backups.reduce ((sum, b) -> sum + b.size), 0
    
    {
      totalBackups: backups.length
      totalSize: totalSize
      oldestBackup: backups[backups.length - 1]?.createdAt
      latestBackup: backups[0]?.createdAt
    }
  
  # Export backup to external location
  exportBackup: (filename, destinationPath) ->
    try
      sourcePath = path.join(@backupDir, filename)
      
      unless fs.existsSync(sourcePath)
        return { success: false, error: 'Backup file not found' }
      
      fs.copyFileSync(sourcePath, destinationPath)
      { success: true, destination: destinationPath }
    catch e
      console.error 'Failed to export backup:', e
      { success: false, error: e.message }
  
  # Import backup from external location
  importBackup: (sourcePath) ->
    try
      unless fs.existsSync(sourcePath)
        return { success: false, error: 'Source file not found' }
      
      filename = path.basename(sourcePath)
      destinationPath = path.join(@backupDir, filename)
      
      fs.copyFileSync(sourcePath, destinationPath)
      { success: true, filename: filename }
    catch e
      console.error 'Failed to import backup:', e
      { success: false, error: e.message }

module.exports = { BackupManager }
