#!/bin/bash

# Enhanced Claude GitHub Token Manager
# Manages personal access tokens using a central config file

set -e  # Exit on any error

# Configuration file paths (will be set by init_config)
CLAUDE_DESKTOP_CONFIG=""
CLAUDE_CODE_CONFIG=""
TOKEN_CONFIG=""

# Allow overriding config paths via environment variables
[[ -n "${CTM_CLAUDE_DESKTOP_CONFIG:-}" ]] && CLAUDE_DESKTOP_CONFIG="$CTM_CLAUDE_DESKTOP_CONFIG"
[[ -n "${CTM_CLAUDE_CODE_CONFIG:-}" ]] && CLAUDE_CODE_CONFIG="$CTM_CLAUDE_CODE_CONFIG"
[[ -n "${CTM_TOKEN_CONFIG:-}" ]] && TOKEN_CONFIG="$CTM_TOKEN_CONFIG"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_highlight() {
    echo -e "${CYAN}$1${NC}"
}

print_prompt() {
    echo -e "${MAGENTA}$1${NC}"
}

# Function to detect OS and set appropriate paths
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            echo "macos"
            ;;
        Linux*)
            echo "linux"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Function to initialize configuration paths
init_config() {
    local os_type=$(detect_os)
    
    # Only set paths if not already set via environment variables
    if [[ -z "$CLAUDE_DESKTOP_CONFIG" ]]; then
        case "$os_type" in
            macos)
                CLAUDE_DESKTOP_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
                ;;
            linux)
                # Check common Linux paths
                if [[ -d "$HOME/.config/Claude" ]]; then
                    CLAUDE_DESKTOP_CONFIG="$HOME/.config/Claude/claude_desktop_config.json"
                elif [[ -d "$HOME/.local/share/Claude" ]]; then
                    CLAUDE_DESKTOP_CONFIG="$HOME/.local/share/Claude/claude_desktop_config.json"
                else
                    CLAUDE_DESKTOP_CONFIG="$HOME/.config/Claude/claude_desktop_config.json"
                fi
                ;;
            windows)
                # Windows paths when using Git Bash or WSL
                if [[ -n "$APPDATA" ]]; then
                    CLAUDE_DESKTOP_CONFIG="$APPDATA/Claude/claude_desktop_config.json"
                else
                    CLAUDE_DESKTOP_CONFIG="$HOME/AppData/Roaming/Claude/claude_desktop_config.json"
                fi
                ;;
            *)
                print_warning "Unknown OS. Using default paths."
                CLAUDE_DESKTOP_CONFIG="$HOME/.config/Claude/claude_desktop_config.json"
                ;;
        esac
    fi
    
    if [[ -z "$CLAUDE_CODE_CONFIG" ]]; then
        # Claude Code config is typically in ~/.config/claude-code on all platforms
        CLAUDE_CODE_CONFIG="$HOME/.config/claude-code/config.json"
    fi
    
    if [[ -z "$TOKEN_CONFIG" ]]; then
        # Default token storage location
        TOKEN_CONFIG="$HOME/.config/claude-token-manager/tokens.json"
    fi
    
    # Create config directories if they don't exist
    mkdir -p "$(dirname "$TOKEN_CONFIG")" 2>/dev/null || true
}

# Function to check if jq is installed
check_jq() {
    if ! command -v jq &> /dev/null; then
        print_error "jq is required but not installed. Please install it first:"
        echo "  macOS: brew install jq"
        echo "  Ubuntu/Debian: sudo apt-get install jq"
        echo "  Windows: download from https://github.com/jqlang/jq/releases"
        exit 1
    fi
}

# Function to initialize token config file
init_token_config() {
    if [[ ! -f "$TOKEN_CONFIG" ]]; then
        print_status "Creating token configuration file at $TOKEN_CONFIG"
        mkdir -p "$(dirname "$TOKEN_CONFIG")"
        # Create with secure permissions (owner read/write only)
        touch "$TOKEN_CONFIG"
        chmod 600 "$TOKEN_CONFIG"
        echo '{}' > "$TOKEN_CONFIG"
        print_success "Token configuration file created with secure permissions"
    else
        # Ensure existing file has secure permissions
        chmod 600 "$TOKEN_CONFIG" 2>/dev/null || true
    fi
}

# Function to backup a file
backup_file() {
    local file="$1"
    local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [[ -f "$file" ]]; then
        cp "$file" "$backup"
        # Secure the backup file
        chmod 600 "$backup" 2>/dev/null || true
        print_status "Backed up $file to $backup"
    fi
}

# Function to validate token format
validate_token() {
    local token="$1"
    # More thorough validation of GitHub token format
    # Classic tokens: ghp_ followed by 36 alphanumeric characters
    # Fine-grained tokens: github_pat_ followed by 82 alphanumeric characters
    if [[ "$token" =~ ^ghp_[A-Za-z0-9_]{36}$ ]] || [[ "$token" =~ ^github_pat_[A-Za-z0-9_]{82}$ ]]; then
        return 0
    fi
    return 1
}

# Function to sanitize input (remove dangerous characters)
sanitize_name() {
    local input="$1"
    # Only allow alphanumeric, underscore, and hyphen
    echo "$input" | sed 's/[^a-zA-Z0-9_-]//g'
}

# Function to add a token to the config
add_token() {
    local name="$1"
    local token="$2"
    
    init_token_config
    
    if [[ -z "$name" ]]; then
        read -p "Enter token name: " name
    fi
    
    # Sanitize the token name
    name=$(sanitize_name "$name")
    if [[ -z "$name" ]]; then
        print_error "Invalid token name. Use only letters, numbers, hyphens, and underscores."
        return 1
    fi
    
    # Always use interactive input for tokens to avoid command history exposure
    if [[ -z "$token" ]]; then
        read -s -p "Enter GitHub token: " token
        echo
    else
        print_warning "For security, tokens should not be passed as command arguments."
        print_status "The token will be read interactively instead."
        read -s -p "Enter GitHub token: " token
        echo
    fi
    
    if ! validate_token "$token"; then
        print_warning "Token doesn't start with 'ghp_' or 'github_pat_' - are you sure this is correct?"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Aborted"
            return 1
        fi
    fi
    
    # Check if name already exists
    if jq -e --arg name "$name" '.[$name]' "$TOKEN_CONFIG" >/dev/null 2>&1; then
        print_warning "Token '$name' already exists"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Aborted"
            return 1
        fi
    fi
    
    # Add token to config with secure temp file handling
    local temp_file=$(mktemp)
    # Set secure permissions on temp file immediately
    chmod 600 "$temp_file"
    
    # Use jq safely with proper error handling
    if jq --arg name "$name" --arg token "$token" '. + {($name): $token}' "$TOKEN_CONFIG" > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$TOKEN_CONFIG"
        chmod 600 "$TOKEN_CONFIG"
    else
        rm -f "$temp_file"
        print_error "Failed to update token configuration"
        return 1
    fi
    
    print_success "Token '$name' added successfully"
}

# Function to list tokens
list_tokens() {
    init_token_config
    
    local tokens=$(jq -r 'keys[]' "$TOKEN_CONFIG" 2>/dev/null)
    
    if [[ -z "$tokens" ]]; then
        print_warning "No tokens found in configuration"
        echo "Use: $0 add <name> [token] to add a token"
        return 0
    fi
    
    print_highlight "Available tokens:"
    local i=1
    while IFS= read -r name; do
        local token=$(jq -r --arg name "$name" '.[$name]' "$TOKEN_CONFIG")
        # Only show last 4 characters for better security
        local masked="****${token: -4}"
        echo "  $i. $name ($masked)"
        ((i++))
    done <<< "$tokens"
}

# Function to remove a token
remove_token() {
    local name="$1"
    
    init_token_config
    
    if [[ -z "$name" ]]; then
        list_tokens
        echo
        read -p "Enter token name to remove: " name
    fi
    
    if ! jq -e --arg name "$name" '.[$name]' "$TOKEN_CONFIG" >/dev/null 2>&1; then
        print_error "Token '$name' not found"
        return 1
    fi
    
    print_warning "About to remove token '$name'"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Aborted"
        return 1
    fi
    
    local temp_file=$(mktemp)
    # Set secure permissions on temp file immediately
    chmod 600 "$temp_file"
    
    if jq --arg name "$name" 'del(.[$name])' "$TOKEN_CONFIG" > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$TOKEN_CONFIG"
        chmod 600 "$TOKEN_CONFIG"
        print_success "Token '$name' removed successfully"
    else
        rm -f "$temp_file"
        print_error "Failed to remove token"
        return 1
    fi
}

# Function to interactively select a token
select_token() {
    init_token_config
    
    local tokens=$(jq -r 'keys[]' "$TOKEN_CONFIG" 2>/dev/null)
    
    if [[ -z "$tokens" ]]; then
        print_error "No tokens found in configuration"
        echo "Use: $0 add <name> [token] to add a token first"
        return 1
    fi
    
    # Count tokens
    local token_count=$(echo "$tokens" | wc -l)
    
    if [[ $token_count -eq 1 ]]; then
        # Only one token, use it automatically
        echo "$tokens"
        return 0
    fi
    
    # Multiple tokens, show selection menu
    print_highlight "Select a token:"
    local i=1
    local -a token_array
    while IFS= read -r name; do
        token_array[$i]="$name"
        local token=$(jq -r --arg name "$name" '.[$name]' "$TOKEN_CONFIG")
        # Only show last 4 characters for better security
        local masked="****${token: -4}"
        echo "  $i. $name ($masked)"
        ((i++))
    done <<< "$tokens"
    
    echo
    while true; do
        read -p "Enter selection (1-$token_count): " selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le $token_count ]]; then
            echo "${token_array[$selection]}"
            return 0
        else
            print_error "Invalid selection. Please enter a number between 1 and $token_count"
        fi
    done
}

# Function to get token by name
get_token() {
    local name="$1"
    init_token_config
    
    local token=$(jq -r --arg name "$name" '.[$name] // empty' "$TOKEN_CONFIG")
    if [[ -n "$token" && "$token" != "null" ]]; then
        echo "$token"
        return 0
    else
        return 1
    fi
}

# Function to update token in a config file
update_token() {
    local config_file="$1"
    local new_token="$2"
    local config_name="$3"
    
    print_status "Processing $config_name configuration..."
    
    if [[ ! -f "$config_file" ]]; then
        print_warning "$config_file not found, skipping..."
        return 0
    fi
    
    # Backup the file
    backup_file "$config_file"
    
    # Check if the file has valid JSON
    if ! jq empty "$config_file" 2>/dev/null; then
        print_error "Invalid JSON in $config_file"
        return 1
    fi
    
    # Update the token - this handles the common structure where GitHub config is nested
    local temp_file=$(mktemp)
    # Set secure permissions on temp file immediately
    chmod 600 "$temp_file"
    
    # Try to update token in various possible locations in the JSON structure
    if jq -e '.mcpServers.github.env.GITHUB_PERSONAL_ACCESS_TOKEN' "$config_file" >/dev/null 2>&1; then
        jq --arg token "$new_token" '.mcpServers.github.env.GITHUB_PERSONAL_ACCESS_TOKEN = $token' "$config_file" > "$temp_file"
        print_status "Updated token in .mcpServers.github.env.GITHUB_PERSONAL_ACCESS_TOKEN"
    elif jq -e '.github.token' "$config_file" >/dev/null 2>&1; then
        jq --arg token "$new_token" '.github.token = $token' "$config_file" > "$temp_file"
        print_status "Updated token in .github.token"
    elif jq -e '.github.personalAccessToken' "$config_file" >/dev/null 2>&1; then
        jq --arg token "$new_token" '.github.personalAccessToken = $token' "$config_file" > "$temp_file"
        print_status "Updated token in .github.personalAccessToken"
    elif jq -e '.mcpServers.github.args' "$config_file" >/dev/null 2>&1; then
        jq --arg token "$new_token" '
            if .mcpServers.github.args then
                .mcpServers.github.args = (.mcpServers.github.args | map(
                    if test("^(ghp_|github_pat_)") then $token else . end
                ))
            else . end
        ' "$config_file" > "$temp_file"
        print_status "Updated token in .mcpServers.github.args array"
    else
        print_warning "GitHub token field not found in $config_file"
        # Don't expose internal structure in error messages
        rm -f "$temp_file"
        return 0
    fi
    
    # Verify the updated JSON is valid
    if jq empty "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$config_file"
        # Ensure config file has secure permissions
        chmod 600 "$config_file" 2>/dev/null || true
        print_success "Successfully updated $config_name"
    else
        print_error "Generated invalid JSON for $config_name, rolling back..."
        rm -f "$temp_file"
        return 1
    fi
}

# Function to show current token in configs
show_current_tokens() {
    print_status "Current GitHub tokens in configurations (masked):"
    
    for config in "$CLAUDE_DESKTOP_CONFIG:Claude Desktop" "$CLAUDE_CODE_CONFIG:Claude Code"; do
        IFS=':' read -r file name <<< "$config"
        if [[ -f "$file" ]]; then
            echo -n "  $name: "
            local token=""
            if jq -e '.mcpServers.github.env.GITHUB_PERSONAL_ACCESS_TOKEN' "$file" >/dev/null 2>&1; then
                token=$(jq -r '.mcpServers.github.env.GITHUB_PERSONAL_ACCESS_TOKEN' "$file")
            elif jq -e '.github.token' "$file" >/dev/null 2>&1; then
                token=$(jq -r '.github.token' "$file")
            elif jq -e '.github.personalAccessToken' "$file" >/dev/null 2>&1; then
                token=$(jq -r '.github.personalAccessToken' "$file")
            fi
            
            if [[ -n "$token" && "$token" != "null" ]]; then
                # Only show last 4 characters for better security
                echo "****${token: -4}"
            else
                echo "Not found"
            fi
        else
            echo "  $name: File not found"
        fi
    done
    
    echo
    print_status "Available tokens in store:"
    list_tokens
}

# Function to use a token (apply it to configs)
use_token() {
    local token_name="$1"
    
    if [[ -z "$token_name" ]]; then
        token_name=$(select_token)
        if [[ $? -ne 0 ]]; then
            return 1
        fi
    fi
    
    local token=$(get_token "$token_name")
    if [[ $? -ne 0 ]]; then
        print_error "Token '$token_name' not found"
        print_status "Available tokens:"
        list_tokens
        return 1
    fi
    
    # Only show last 4 characters for better security
    local masked="****${token: -4}"
    print_status "Using token '$token_name' ($masked)"
    echo
    
    # Update both configuration files
    local success=true
    
    update_token "$CLAUDE_DESKTOP_CONFIG" "$token" "Claude Desktop" || success=false
    echo
    update_token "$CLAUDE_CODE_CONFIG" "$token" "Claude Code" || success=false
    
    echo
    if $success; then
        print_success "Token '$token_name' applied to all configurations!"
        echo
        print_status "Next steps:"
        echo "  1. Restart Claude Desktop application"
        echo "  2. Restart any running claude-code processes"
        echo "  3. Test GitHub integration"
    else
        print_error "Some updates failed. Check the output above."
        return 1
    fi
}

# Function to show help
show_help() {
    echo "🔑 Enhanced Claude GitHub Token Manager"
    echo "======================================="
    echo
    echo "USAGE:"
    echo "  $0 <command> [arguments]"
    echo
    echo "COMMANDS:"
    echo "  init                  Initialize configuration paths and show detected locations"
    echo "  add <name>            Add a new token to the store (interactive input)"
    echo "  list                  List all stored tokens (masked)"
    echo "  remove <name>         Remove a token from the store"
    echo "  use [name]            Apply a token to Claude configs (interactive if no name)"
    echo "  status                Show current tokens in configs and store"
    echo "  help                  Show this help message"
    echo
    echo "EXAMPLES:"
    echo "  $0 init                                 # Show configuration paths"
    echo "  $0 add personal                         # Add a token (will prompt for token)"
    echo "  $0 add work                             # Add a token interactively"
    echo "  $0 list                                 # List all tokens"
    echo "  $0 use personal                         # Use 'personal' token"
    echo "  $0 use                                  # Interactive token selection"
    echo "  $0 remove old-token                     # Remove a token"
    echo "  $0 status                               # Show current status"
    echo
    echo "ENVIRONMENT VARIABLES:"
    echo "  CTM_CLAUDE_DESKTOP_CONFIG  Override Claude Desktop config path"
    echo "  CTM_CLAUDE_CODE_CONFIG     Override Claude Code config path"
    echo "  CTM_TOKEN_CONFIG           Override token storage path"
    echo
    echo "CONFIG FILE:"
    echo "  Tokens are stored in: $TOKEN_CONFIG"
    echo "  Format: {\"name\": \"token\", \"name2\": \"token2\"}"
}

# Function to show configuration info
show_init() {
    print_highlight "Claude Token Manager Configuration"
    echo "==================================="
    echo
    print_status "Detected OS: $(detect_os)"
    echo
    print_status "Configuration paths:"
    echo "  Claude Desktop: $CLAUDE_DESKTOP_CONFIG"
    if [[ -f "$CLAUDE_DESKTOP_CONFIG" ]]; then
        echo "    ✓ File exists"
    else
        echo "    ✗ File not found (will be created when needed)"
    fi
    echo
    echo "  Claude Code: $CLAUDE_CODE_CONFIG"
    if [[ -f "$CLAUDE_CODE_CONFIG" ]]; then
        echo "    ✓ File exists"
    else
        echo "    ✗ File not found (will be created when needed)"
    fi
    echo
    echo "  Token Storage: $TOKEN_CONFIG"
    if [[ -f "$TOKEN_CONFIG" ]]; then
        echo "    ✓ File exists"
    else
        echo "    ✗ File not found (will be created on first use)"
    fi
    echo
    print_status "To override these paths, set environment variables:"
    echo "  export CTM_CLAUDE_DESKTOP_CONFIG='/custom/path/claude_desktop_config.json'"
    echo "  export CTM_CLAUDE_CODE_CONFIG='/custom/path/config.json'"
    echo "  export CTM_TOKEN_CONFIG='/custom/path/tokens.json'"
}

# Main script
main() {
    # Check dependencies
    check_jq
    
    # Initialize configuration paths
    init_config
    
    # Parse command line arguments
    case "${1:-}" in
        "init")
            show_init
            ;;
        "add")
            # Never accept token as command line argument for security
            add_token "${2:-}" ""
            ;;
        "list"|"ls")
            list_tokens
            ;;
        "remove"|"rm"|"delete")
            remove_token "${2:-}"
            ;;
        "use"|"apply")
            use_token "${2:-}"
            ;;
        "status"|"show")
            show_current_tokens
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        "")
            print_error "Please specify a command"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
        *)
            print_error "Unknown command: $1"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
