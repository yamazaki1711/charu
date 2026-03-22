# Stitch MCP Setup Guide for CHARU

## Quick Setup (Automated)

Run the setup script:
```bash
scripts\setup-stitch-mcp.bat
```

This script will:
1. Check Node.js installation
2. Check Google Cloud CLI installation
3. Open browser for Google login
4. Set up OAuth credentials
5. Configure your project

---

## Manual Setup

### Step 1: Install Node.js

Download and install from: https://nodejs.org/

Verify:
```bash
node --version
npm --version
```

### Step 2: Install Google Cloud CLI

Download from: https://cloud.google.com/sdk/docs/install

Verify:
```bash
gcloud --version
```

### Step 3: Authenticate

```bash
# Login to Google Cloud
gcloud auth login

# Set up application credentials
gcloud auth application-default login
```

### Step 4: Set Project

```bash
# List available projects
gcloud projects list

# Set your project
gcloud config set project YOUR_PROJECT_ID
```

### Step 5: Enable Stitch API

```bash
gcloud services enable stitch.googleapis.com
```

### Step 6: Configure MCP

The `mcp.json` file is already configured. Just update the project ID:

```json
{
  "mcpServers": {
    "stitch": {
      "command": "npx",
      "args": ["-y", "stitch-mcp"],
      "env": {
        "GOOGLE_CLOUD_PROJECT": "YOUR_PROJECT_ID"
      }
    }
  }
}
```

---

## Troubleshooting

### "Node.js not found"
Install Node.js from https://nodejs.org/ and restart terminal.

### "gcloud not found"
Install Google Cloud CLI from https://cloud.google.com/sdk/docs/install

### "No project set"
Run: `gcloud config set project YOUR_PROJECT_ID`

### "API not enabled"
Run: `gcloud services enable stitch.googleapis.com`

---

## Available Tools

Once connected, Stitch MCP provides:

| Tool | Description |
|------|-------------|
| `generate_screen_from_text` | Generate UI from text description |
| `fetch_screen_image` | Get screen screenshot |
| `fetch_screen_code` | Get screen HTML/CSS code |
| `list_projects` | List all Stitch projects |
| `list_screens` | List screens in a project |
| `extract_design_context` | Extract design system from screen |

---

## Example Usage

After setup, you can ask:

```
"Generate a login screen for CHARU app with Chinese text support"
"Show me all screens in my project"
"Extract design context from the home screen"
```
