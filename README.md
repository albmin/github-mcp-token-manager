# Claude GitHub Token Manager

A powerful cross-platform command-line utility for managing GitHub personal access tokens across Claude Desktop and Claude Code configurations. This tool provides a centralized token store with easy switching between different GitHub accounts and projects.

## ⚠️ Security Notice

**IMPORTANT**: This tool handles sensitive GitHub access tokens. Please follow these security best practices:

- **Never** pass tokens as command-line arguments (they'll be saved in shell history)
- **Always** use the interactive prompt for entering tokens
- Token files are automatically secured with 600 permissions (owner read/write only)
- Tokens are masked in output, showing only the last 4 characters
- Review the Security Features section below for full details

## 🚀 Features

- **Cross-Platform Support**: Automatically detects and configures paths for macOS, Linux, and Windows
- **Centralized Token Storage**: Store multiple GitHub tokens with friendly names
- **Interactive Token Selection**: Easy switching between tokens with numbered menus
- **Automatic Backups**: Timestamped backups before any configuration changes
- **Security First**: Masked token display and validation
- **Multi-Application Support**: Works with both Claude Desktop and Claude Code
- **JSON Path Detection**: Automatically finds tokens in various JSON structures
- **Error Recovery**: Rollback capability if updates fail
- **Environment Variable Overrides**: Customize paths for your specific setup

## 📁 File Structure

```
claude-token-manager/
├── claude-token-manager.sh    # Main script
└── README.md                  # This file
```

Token storage and configuration files are automatically created in platform-appropriate locations.

## 🛠️ Installation

### Prerequisites

1. **Install jq** (required for JSON manipulation):
   ```bash
   # macOS
   brew install jq
   
   # Ubuntu/Debian
   sudo apt-get install jq
   
   # Windows (using Chocolatey)
   choco install jq
   
   # Or download from https://github.com/jqlang/jq/releases
   ```

### Quick Setup

1. **Clone or download the repository**:
   ```bash
   git clone https://github.com/yourusername/claude-token-manager.git
   cd claude-token-manager
   ```

2. **Make the script executable**:
   ```bash
   chmod +x claude-token-manager.sh
   ```

3. **Initialize and check configuration** (recommended):
   ```bash
   ./claude-token-manager.sh init
   ```
   This will show you where configuration files will be stored on your system.

4. **Create a symlink for easy access** (optional):
   ```bash
   # macOS/Linux
   sudo ln -s $(pwd)/claude-token-manager.sh /usr/local/bin/claude-tokens
   
   # Now you can use it from anywhere:
   claude-tokens status
   ```

## 📖 Usage

### Basic Commands

#### Initialize Configuration (First Time Setup)

```bash
# Check detected paths and configuration
./claude-token-manager.sh init

# Output shows:
# - Detected operating system
# - Claude Desktop config path
# - Claude Code config path  
# - Token storage location
# - Instructions for customizing paths
```

#### Add Tokens to the Store

```bash
# Add a token interactively (RECOMMENDED - will prompt for token)
./claude-token-manager.sh add personal
./claude-token-manager.sh add work

# The script will prompt you to enter the token securely:
# Enter token name: personal
# Enter GitHub token: [hidden input]

# Add with descriptive names
./claude-token-manager.sh add finapp-project
./claude-token-manager.sh add company-main
```

**Security Note**: Never pass tokens as command-line arguments as they will be saved in your shell history and visible to other users via process listings.

#### List Stored Tokens

```bash
./claude-token-manager.sh list
# Output:
# Available tokens:
#   1. personal (****ef12)
#   2. work (****ab34)
#   3. finapp-project (****cd56)
```

#### Use a Token (Apply to Claude Configs)

```bash
# Use a specific token
./claude-token-manager.sh use personal

# Interactive selection (if multiple tokens exist)
./claude-token-manager.sh use
# Select a token:
#   1. personal (****ef12)
#   2. work (****ab34)
#   3. finapp-project (****cd56)
# Enter selection (1-3): 1
```

#### Remove Tokens

```bash
# Remove a specific token
./claude-token-manager.sh remove old-token

# Interactive removal (will list tokens first)
./claude-token-manager.sh remove
```

#### Check Status

```bash
./claude-token-manager.sh status
# Shows:
# - Current tokens in Claude Desktop config
# - Current tokens in Claude Code config  
# - All available tokens in the store
```

### Command Reference

| Command | Aliases | Description | Example |
|---------|---------|-------------|---------|
| `init` | | Show configuration paths | `init` |
| `add <name>` | | Add a new token (interactive) | `add work` |
| `list` | `ls` | List all stored tokens | `list` |
| `use [name]` | `apply` | Apply token to configs | `use personal` |
| `remove <n>` | `rm`, `delete` | Remove a token | `remove old-token` |
| `status` | `show` | Show current status | `status` |
| `help` | `-h`, `--help` | Show help message | `help` |

## 🔧 Configuration

### Automatic Path Detection

The script automatically detects your operating system and sets appropriate paths:

**macOS:**
- Claude Desktop: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Claude Code: `~/.config/claude-code/config.json`
- Token Storage: `~/.config/claude-token-manager/tokens.json`

**Linux:**
- Claude Desktop: `~/.config/Claude/claude_desktop_config.json` (or `~/.local/share/Claude/`)
- Claude Code: `~/.config/claude-code/config.json`
- Token Storage: `~/.config/claude-token-manager/tokens.json`

**Windows (Git Bash/WSL):**
- Claude Desktop: `%APPDATA%/Claude/claude_desktop_config.json`
- Claude Code: `~/.config/claude-code/config.json`
- Token Storage: `~/.config/claude-token-manager/tokens.json`

### Environment Variable Overrides

You can customize the configuration paths using environment variables:

```bash
# Set custom paths
export CTM_CLAUDE_DESKTOP_CONFIG="/custom/path/claude_desktop_config.json"
export CTM_CLAUDE_CODE_CONFIG="/custom/path/config.json"
export CTM_TOKEN_CONFIG="/custom/path/tokens.json"

# The script will use your custom paths
./claude-token-manager.sh status
```

Add these to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.) to make them permanent:

```bash
# Add to ~/.bashrc or ~/.zshrc
export CTM_TOKEN_CONFIG="$HOME/Dropbox/claude-tokens.json"  # Sync across machines
```

### Token Storage Format

Tokens are stored in JSON format at `~/.config/claude-token-manager/tokens.json` (or your custom path):

```json
{
  "personal": "ghp_1234567890abcdef...",
  "work": "ghp_abcdefghijklmnop...",
  "finapp-project": "ghp_qrstuvwxyz123456...",
  "company-main": "github_pat_ABC123..."
}
```

### Supported JSON Structures

The script handles various token storage patterns in Claude configurations:

```json
// Pattern 1: MCP Server environment variable
{
  "mcpServers": {
    "github": {
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_..."
      }
    }
  }
}

// Pattern 2: Direct github object
{
  "github": {
    "token": "ghp_..."
  }
}

// Pattern 3: Personal access token field
{
  "github": {
    "personalAccessToken": "ghp_..."
  }
}

// Pattern 4: Arguments array
{
  "mcpServers": {
    "github": {
      "args": ["--token", "ghp_..."]
    }
  }
}
```

## 🛡️ Security Features

### Secure Token Input
- Tokens are **always** entered interactively to prevent command history exposure
- Input is hidden (like password entry) when typing tokens
- Command-line token arguments are rejected for security

### File Permissions
- Token storage files are automatically secured with 600 permissions (owner read/write only)
- Backup files are also secured with 600 permissions
- Temporary files are created with secure permissions immediately

### Token Validation
- Validates GitHub token format:
  - Classic tokens: `ghp_` followed by 36 alphanumeric characters
  - Fine-grained tokens: `github_pat_` followed by 82 alphanumeric characters
- Warns for non-standard token formats
- Token names are sanitized to prevent injection attacks

### Masked Display
- Shows only last 4 characters for enhanced security
- Example: `****5678` instead of full token
- Reduces risk from shoulder surfing or screen sharing

### Automatic Backups
- Creates timestamped backups before changes
- Format: `filename.backup.YYYYMMDD_HHMMSS`
- Backup files secured with 600 permissions
- Stored in same directory as original file

### Error Recovery
- JSON validation before applying changes
- Automatic rollback if updates fail
- Secure cleanup of temporary files on errors
- Preserves original files on error

## 🎯 Workflow Examples

### Initial Setup
```bash
# 1. Check your configuration
./claude-token-manager.sh init

# 2. Add your tokens (will prompt for secure input)
./claude-token-manager.sh add personal
./claude-token-manager.sh add work

# 3. Check they were added
./claude-token-manager.sh list

# 4. Apply your personal token
./claude-token-manager.sh use personal
```

### Switching Between Projects
```bash
# Working on personal project
./claude-token-manager.sh use personal

# Switch to work project  
./claude-token-manager.sh use work

# Quick interactive switch
./claude-token-manager.sh use
```

### Managing Multiple GitHub Accounts
```bash
# Add tokens for different purposes (will prompt for secure input)
./claude-token-manager.sh add github-main
./claude-token-manager.sh add github-oss
./claude-token-manager.sh add github-client

# Switch as needed
./claude-token-manager.sh use github-client  # Client work
./claude-token-manager.sh use github-oss     # Open source contributions
./claude-token-manager.sh use github-main    # Personal projects
```

### Using Custom Paths
```bash
# Store tokens in cloud-synced folder
export CTM_TOKEN_CONFIG="$HOME/Dropbox/Security/claude-tokens.json"

# Use different Claude config location
export CTM_CLAUDE_DESKTOP_CONFIG="/opt/claude/config.json"

# Check the configuration
./claude-token-manager.sh init
```

## 🐛 Troubleshooting

### Common Issues

**1. "jq: command not found"**
```bash
# Install jq
brew install jq  # macOS
sudo apt-get install jq  # Ubuntu/Debian
choco install jq  # Windows with Chocolatey
```

**2. "Permission denied"**
```bash
# Make script executable
chmod +x claude-token-manager.sh
```

**3. "Invalid JSON in config file"**
- Check the backup files for recovery
- Manually fix JSON syntax errors
- Use `jq` to validate: `jq empty config.json`

**4. "Token field not found"**
- The script will show available JSON keys
- Your config might use a different structure
- Use environment variables to specify custom paths

**5. "Config file not found"**
- Run `./claude-token-manager.sh init` to see where files are expected
- Create the directory if needed: `mkdir -p ~/.config/claude-code`
- Use environment variables to point to existing configs

### Backup Recovery

If something goes wrong, restore from backup:

```bash
# Find backup files (example for macOS)
ls -la ~/Library/Application\ Support/Claude/*.backup.*

# Restore a backup
cp ~/Library/Application\ Support/Claude/claude_desktop_config.json.backup.20241215_143045 \
   ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

### Debug Mode

For troubleshooting, you can manually inspect configurations:

```bash
# Check current Claude Desktop config (adjust path for your OS)
jq '.mcpServers.github' ~/Library/Application\ Support/Claude/claude_desktop_config.json

# Check token store
jq '.' ~/.config/claude-token-manager/tokens.json

# Validate JSON files
jq empty ~/.config/claude-code/config.json
```

## 🔄 Integration with Claude

After updating tokens:

1. **Restart Claude Desktop**: Quit and reopen the application
2. **Restart Claude Code**: Stop any running processes and restart
3. **Test GitHub Access**: Try a GitHub operation in Claude to verify

## 📝 License

This utility is provided as-is for managing Claude GitHub configurations. Use at your own risk and always keep backups of your configuration files.

## 🤝 Contributing

Feel free to modify the script for your specific needs. Common customizations:

- Add support for additional config file locations
- Extend JSON path detection for other structures  
- Add integration with other Claude tools
- Enhance security features
- Add support for other token types (GitLab, Bitbucket, etc.)

### Development Tips

1. **Testing on Different Platforms**: Use the `init` command to verify path detection
2. **Adding New Patterns**: Extend the `update_token` function for new JSON structures
3. **Custom Storage Backends**: Modify `init_token_config` to use different storage methods

---

**Happy token managing! 🎉**