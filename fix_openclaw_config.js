const fs = require('fs');
const path = require('path');

const configFile = path.join(process.env.HOME, '.openclaw/openclaw.json');

if (!fs.existsSync(configFile)) {
  console.error('OpenClaw config not found:', configFile);
  process.exit(1);
}

const data = JSON.parse(fs.readFileSync(configFile, 'utf8'));

// Fix agent model configuration
if (data.agents && data.agents.defaults) {
  if (data.agents.defaults.model) {
    data.agents.defaults.model.primary = 'glm/glm-4-flash';
  }
  if (data.agents.defaults.models) {
    // Remove old format keys and add new format
    const oldKeys = Object.keys(data.agents.defaults.models).filter(k => k.startsWith('glm/'));
    for (const k of oldKeys) {
      delete data.agents.defaults.models[k];
    }
    data.agents.defaults.models['glm/glm-4-flash'] = {};
  }
}

fs.writeFileSync(configFile, JSON.stringify(data, null, 2));
console.log('OpenClaw config fixed');
