#!/bin/bash

# Simple SSH Key Setup Script
# Creates ed25519 SSH key, config file, and adds to ssh-agent
#
# Usage:
#   Interactive mode (prompts for input):
#     ./ssh_setup.sh
#
#   Command line mode:
#     ./ssh_setup.sh [key_name] [comment] [host] [user] [hostname]
#
#   Examples:
#     ./ssh_setup.sh                                    # Interactive mode
#     ./ssh_setup.sh my_key                             # Custom key name only
#     ./ssh_setup.sh my_key "Work laptop"               # Key name + comment
#     ./ssh_setup.sh my_key "Work laptop" work-server   # Key name + comment + host alias
#     ./ssh_setup.sh github_key "GitHub" github.com git # Full GitHub setup
#     ./ssh_setup.sh prod_key "Production" prod john 192.168.1.100  # Full server setup

set -e  # Exit on any error

SSH_DIR="$HOME/.ssh"

# Interactive mode if no arguments provided
if [ $# -eq 0 ]; then
    echo "SSH Key Setup - Interactive Mode"
    echo "================================"
    
    read -p "Key name (default: id_ed25519): " KEY_NAME
    KEY_NAME=${KEY_NAME:-"id_ed25519"}
    
    read -p "Comment (optional): " COMMENT
    
    read -p "Host (default: *): " HOST
    HOST=${HOST:-"*"}
    
    read -p "User (optional): " USER
    
    read -p "Hostname (optional): " HOSTNAME
    
    echo
else
    # Command line arguments mode
    KEY_NAME=${1:-"id_ed25519"}
    COMMENT=${2:-""}
    HOST=${3:-"*"}
    USER=${4:-""}
    HOSTNAME=${5:-""}
fi

# Create ~/.ssh directory if it doesn't exist
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Full path to the key files
PRIVATE_KEY="$SSH_DIR/$KEY_NAME"
PUBLIC_KEY="$SSH_DIR/$KEY_NAME.pub"

# Check if key already exists
if [ -f "$PRIVATE_KEY" ] || [ -f "$PUBLIC_KEY" ]; then
    echo "Warning: SSH key '$KEY_NAME' already exists!"
    echo "  Private key: $PRIVATE_KEY"
    echo "  Public key:  $PUBLIC_KEY"
    
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled. Please run the script again with a different key name."
        exit 1
    fi
    
    echo "Overwriting existing key..."
fi

# Generate the SSH key
echo "Generating ed25519 SSH key: $KEY_NAME"
if [ -n "$COMMENT" ]; then
    ssh-keygen -t ed25519 -f "$PRIVATE_KEY" -C "$COMMENT" -N ""
else
    ssh-keygen -t ed25519 -f "$PRIVATE_KEY" -N ""
fi

# Set proper permissions
chmod 600 "$PRIVATE_KEY"
chmod 644 "$PUBLIC_KEY"

# Add to SSH config
CONFIG_FILE="$SSH_DIR/config"
if [ ! -f "$CONFIG_FILE" ]; then
    # Create new config file
    cat > "$CONFIG_FILE" << EOF
Host $HOST
    AddKeysToAgent yes
    IdentityFile $PRIVATE_KEY$([ -n "$USER" ] && echo "
    User $USER")$([ -n "$HOSTNAME" ] && echo "
    HostName $HOSTNAME")

EOF
    chmod 600 "$CONFIG_FILE"
    echo "Created SSH config file"
else
    # Append to existing config file
    cat >> "$CONFIG_FILE" << EOF

Host $HOST
    AddKeysToAgent yes
    IdentityFile $PRIVATE_KEY$([ -n "$USER" ] && echo "
    User $USER")$([ -n "$HOSTNAME" ] && echo "
    HostName $HOSTNAME")

EOF
    echo "Added key to existing SSH config file"
fi

# Start ssh-agent if not running and add key
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)"
fi

ssh-add "$PRIVATE_KEY"

echo "SSH key setup complete!"
echo "Public key:"
cat "$PUBLIC_KEY"

echo
echo "Note: Please review your SSH config file to ensure it has all required properties:"
echo "  Config file: $CONFIG_FILE"
echo "  You can edit it with: nano $CONFIG_FILE"
echo "  Test your SSH connection with: ssh -T $HOST"