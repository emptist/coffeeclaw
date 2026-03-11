# OpenClaw Workspace Integration Plan

## Goal

Allow CoffeeClaw app to read and display files from OpenClaw workspace (`~/.openclaw/workspace/`).

## Architecture Options

### Option A: File Browser Component (Recommended)

**Implementation:**
1. Add new IPC handler to list/read OpenClaw workspace files
2. Create UI component to browse workspace directory
3. Display files with syntax highlighting

**Code Changes:**

#### 1. Add IPC Handlers in `src/ipc-handlers.coffee`

```coffee
registerOpenClawHandlers: ->
  ipcMain.handle 'list-openclaw-workspace', (event, subdir = '') =>
    workspaceDir = path.join(process.env.HOME, '.openclaw', 'workspace')
    targetDir = path.join(workspaceDir, subdir)
    
    try
      files = fs.readdirSync(targetDir, { withFileTypes: true })
      files.map (f) ->
        name: f.name
        isDirectory: f.isDirectory()
        path: path.join(subdir, f.name)
        size: if f.isFile() then fs.statSync(path.join(targetDir, f.name)).size else 0
    catch e
      console.error 'Failed to list OpenClaw workspace:', e
      []
  
  ipcMain.handle 'read-openclaw-file', (event, filePath) =>
    workspaceDir = path.join(process.env.HOME, '.openclaw', 'workspace')
    fullPath = path.join(workspaceDir, filePath)
    
    # Security: Ensure file is within workspace
    unless fullPath.startsWith(workspaceDir)
      throw new Error 'Access denied: File outside workspace'
    
    try
      content = fs.readFileSync(fullPath, 'utf-8')
      { success: true, content, path: filePath }
    catch e
      { success: false, error: e.message }
```

#### 2. Add to Preload (`src/preload.coffee`)

```coffee
contextBridge.exposeInMainWorld 'api', {
  # ... existing APIs ...
  
  listOpenClawWorkspace: (subdir) -> ipcRenderer.invoke 'list-openclaw-workspace', subdir
  readOpenClawFile: (filePath) -> ipcRenderer.invoke 'read-openclaw-file', filePath
}
```

#### 3. Add UI in `index.html`

```html
<!-- Add button in sidebar -->
<button onclick="showOpenClawWorkspace()" class="tool-btn">
  📁 OpenClaw Files
</button>

<!-- Add workspace viewer -->
<div id="openclawWorkspaceView" class="tool-view" style="display: none;">
  <div class="tool-view-header">
    <button class="back-btn" onclick="showChatView()">← Back</button>
    <h2>OpenClaw Workspace</h2>
  </div>
  <div class="workspace-container">
    <div id="workspaceFileList" class="file-list"></div>
    <div id="workspaceFileContent" class="file-content"></div>
  </div>
</div>

<script>
let currentWorkspacePath = '';

async function showOpenClawWorkspace() {
  document.querySelectorAll('.tool-view').forEach(v => v.style.display = 'none');
  document.getElementById('openclawWorkspaceView').style.display = 'flex';
  await loadWorkspaceFiles('');
}

async function loadWorkspaceFiles(subdir) {
  currentWorkspacePath = subdir;
  const files = await window.api.listOpenClawWorkspace(subdir);
  
  const fileList = document.getElementById('workspaceFileList');
  fileList.innerHTML = '';
  
  // Add parent directory link
  if (subdir) {
    const parentDiv = document.createElement('div');
    parentDiv.className = 'file-item directory';
    parentDiv.innerHTML = '📁 ..';
    parentDiv.onclick = () => loadWorkspaceFiles(path.dirname(subdir));
    fileList.appendChild(parentDiv);
  }
  
  // List files
  files.forEach(file => {
    const div = document.createElement('div');
    div.className = `file-item ${file.isDirectory ? 'directory' : 'file'}`;
    div.innerHTML = `${file.isDirectory ? '📁' : '📄'} ${file.name}`;
    div.onclick = () => {
      if (file.isDirectory) {
        loadWorkspaceFiles(file.path);
      } else {
        viewOpenClawFile(file.path);
      }
    };
    fileList.appendChild(div);
  });
}

async function viewOpenClawFile(filePath) {
  const result = await window.api.readOpenClawFile(filePath);
  const contentDiv = document.getElementById('workspaceFileContent');
  
  if (result.success) {
    contentDiv.innerHTML = `
      <h3>${filePath}</h3>
      <pre>${escapeHtml(result.content)}</pre>
    `;
  } else {
    contentDiv.innerHTML = `<p class="error">Error: ${result.error}</p>`;
  }
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}
</script>
```

### Option B: Agent Files Tab

Add a dedicated tab in the sidebar showing agent-generated files:

```html
<div class="sidebar-section">
  <h3>🤖 Agent Files</h3>
  <div id="agentFilesList"></div>
</div>
```

### Option C: Link to OpenClaw Workspace

Simple solution - add button to open workspace in file explorer:

```coffee
ipcMain.handle 'open-openclaw-workspace', ->
  workspaceDir = path.join(process.env.HOME, '.openclaw', 'workspace')
  shell.openPath(workspaceDir)
```

## Recommended: Option A

**Pros:**
- Full integration in app
- Can view files without leaving app
- Can add features like search, filter, syntax highlighting
- Better UX

**Cons:**
- More code to implement
- Need to handle security (sandboxing)

## Security Considerations

1. **Path Validation:** Ensure files are within workspace directory
2. **File Type Filtering:** Only allow safe file types (md, txt, json, etc.)
3. **Size Limits:** Don't read very large files
4. **No Write Access:** Read-only for safety

## Implementation Steps

1. Add IPC handlers in `src/ipc-handlers.coffee`
2. Add API methods in `src/preload.coffee`
3. Add UI components in `index.html`
4. Add CSS styling
5. Test with various file types

## Example Files to Display

```
~/.openclaw/workspace/
├── .dev_review/
│   └── agent_is_here.md  ← Agent created files
├── IDENTITY.md           ← Agent identity
├── TOOLS.md              ← Available tools
├── USER.md               ← User preferences
└── coffeeclaw/           ← Project reference
```

## Future Enhancements

1. **Search:** Search across all workspace files
2. **Recent Files:** Show recently modified agent files
3. **File Actions:** Copy content, open in editor, share
4. **Real-time Updates:** Watch for file changes
5. **Markdown Rendering:** Render .md files with formatting
