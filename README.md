# ☕ CoffeeClaw

A desktop AI assistant powered by OpenClaw and multiple AI providers.

## Features

- 🖥️ Native desktop app for macOS, Windows, and Linux
- 💬 Multi-session chat management
- 🧰 Integrated tool panels (GitHub, Feishu, File, Web Search, etc.)
- 🎨 Familiar UI designs (Google-style search, GitHub dashboard)
- 🌍 Multi-language support (English, 中文, Esperanto)
- 🔒 Secure local storage for API keys
- 🚀 Easy setup wizard with platform detection
- 🧠 AI-powered learning system (learns from interactions)

## Installation

### Download Release

Download the latest release for your platform:
- **macOS**: `CoffeeClaw-x.x.x.dmg`
- **Windows**: `CoffeeClaw Setup x.x.x.exe`
- **Linux**: `CoffeeClaw-x.x.x.AppImage` or `.deb`

### From Source

```bash
git clone https://github.com/yourusername/coffeeclaw.git
cd coffeeclaw
npm install
npm start
```

## Setup

1. Launch CoffeeClaw
2. Click "Check System" to verify prerequisites
3. Enter your API key (get one free at [open.bigmodel.cn](https://open.bigmodel.cn) or use [OpenRouter](https://openrouter.ai))
4. Start chatting!

### Prerequisites

- **Node.js** (v18+) - Required for OpenClaw
- **npm** - Comes with Node.js
- **OpenClaw** - Auto-installed by setup wizard

### Windows Users

For best experience on Windows, install WSL2:
```bash
wsl --install
```

## Usage

### Chat Interface
- Click ➕ to start a new conversation
- Click any conversation in the sidebar to load its history
- Press `Cmd/Ctrl + Enter` to send message

### Tool Panels

Click the tool buttons in the sidebar to access specialized panels:

| Tool | Design Style | Features |
|------|--------------|----------|
| 🔍 Web Search | Google homepage | Centered search box, "I'm Feeling Lucky" |
| 🐙 GitHub | Dashboard cards | Issues, PRs, Create Issue/PR, Branches |
| 📧 Feishu Workbench | Workbench grid | Messages, Documents, Drive, Wiki |
| 📁 File Management | Card layout | Read, Write, Edit, Create files |
| ⚙️ System Tools | Card grid | Commands, Cron, Weather, Web Fetch, Screenshot, Short URL |

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd/Ctrl + Enter` | Send message |
| `Cmd/Ctrl + N` | New chat |
| `Escape` | Close settings panel |

## API Configuration

CoffeeClaw supports multiple AI providers:

### Zhipu GLM (Recommended - Free + Function Calling)
- **GLM-4-Flash** - Completely FREE with Function Calling support ⭐
- GLM-4-Plus, GLM-4-Air
- 128K context, 72 tokens/s generation speed
- Get API key at [open.bigmodel.cn](https://open.bigmodel.cn)

### OpenRouter (Backup - Limited Free Tier)
- Access to 100+ models including Gemini, Llama
- **Free tier: 50 requests/day** (resets daily)
- Rate limit: 20 requests/minute
- Get API key at [openrouter.ai](https://openrouter.ai)

### OpenAI (Paid Only)
- GPT-4o Mini, GPT-4o, GPT-4 Turbo
- Get API key at [platform.openai.com](https://platform.openai.com/api-keys)

### Provider Strategy
| Use Case | Recommended Provider | Model |
|----------|---------------------|-------|
| Normal bots (chat) | Zhipu GLM-4-Flash | Free + basic function calling |
| OpenClaw agent (execution) | OpenRouter | Need stronger reasoning for tools/skills |

**Important**: GLM-4-Flash supports function calling but is NOT suitable for OpenClaw agent execution tasks. OpenClaw requires models with strong multi-step reasoning and tool orchestration capabilities (Claude, GPT-4, etc.). Use OpenRouter's free tier (50 req/day) for agent execution.

Select your preferred provider and model during setup.

## Local Gateway

CoffeeClaw runs a local gateway at `http://localhost:18789`

You can also use OpenClaw directly from command line:
```bash
# Install OpenClaw
npm install -g openclaw

# Initialize
openclaw init

# Start gateway
openclaw gateway --dev
```

## Privacy

- All API keys stored locally in `.secrete/` folder
- Chat history stored locally in `.secrete/sessions.json`
- No data sent to third parties except the AI provider API

## Development

```bash
# Install dependencies
npm install

# Compile CoffeeScript
npm run compile

# Run in development
npm start

# Build for current platform
npm run build

# Build for all platforms
npm run build:all
```

## Tech Stack

- Electron
- CoffeeScript
- OpenClaw Agent Framework
- Multiple AI Providers (Zhipu, OpenRouter, OpenAI)

## Troubleshooting

### Common Issues

**API Key not working**
- Ensure you're using the correct provider's API key format
- Check that your API key has sufficient credits/quota

**Gateway connection failed**
- Make sure OpenClaw is installed: `npm install -g openclaw`
- Try: `openclaw gateway --dev`

**Session not loading**
- Check `.secrete/sessions.json` for corruption
- Try creating a new session

## License

MIT License - see [LICENSE](LICENSE)

## Credits

- [OpenClaw](https://github.com/openclaw/openclaw) - AI agent framework
- [Zhipu AI](https://open.bigmodel.cn) - GLM language models
- [OpenRouter](https://openrouter.ai) - Multi-model API gateway
