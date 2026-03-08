# ☕ CoffeeClaw

A desktop AI assistant powered by OpenClaw and Zhipu GLM models.

## Features

- 🖥️ Native desktop app for macOS, Windows, and Linux
- 💬 Multi-session chat management
- 🌍 Multi-language support (English, 中文, Esperanto)
- 🔒 Secure local storage for API keys
- 🚀 Easy setup wizard with platform detection

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
3. Enter your Zhipu API key (get one free at [open.bigmodel.cn](https://open.bigmodel.cn))
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

### New Chat
Click the ➕ button in the input bar to start a new conversation.

### Switch Conversations
Click any conversation in the left sidebar to load its history.

### Delete Conversation
Click the × button on any conversation to delete it.

## API Configuration

CoffeeClaw supports multiple AI providers:

### Zhipu GLM (Default - Free tier available)
- GLM-4-Flash (Free) ⭐
- GLM-4-Plus
- GLM-4-Air
- Get API key at [open.bigmodel.cn](https://open.bigmodel.cn)

### OpenAI
- GPT-4o Mini
- GPT-4o
- GPT-4 Turbo
- Get API key at [platform.openai.com](https://platform.openai.com/api-keys)

### DeepSeek
- DeepSeek Chat
- DeepSeek Coder
- Get API key at [platform.deepseek.com](https://platform.deepseek.com)

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
- No data sent to third parties except Zhipu API

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
- Zhipu GLM API

## License

MIT License - see [LICENSE](LICENSE)

## Credits

- [OpenClaw](https://github.com/openclaw/openclaw) - AI agent framework
- [Zhipu AI](https://open.bigmodel.cn) - GLM language models
