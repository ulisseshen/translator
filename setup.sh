#!/bin/bash

# Translator App Setup Script for Unix-like systems (Linux/macOS)
set -e

echo "🚀 Setting up Translator App..."

# Check if Dart is installed
if ! command -v dart &> /dev/null; then
    echo "❌ Dart is not installed. Please install Dart first:"
    echo "   Visit: https://dartbrasil.dev/get-dart"
    exit 1
fi

echo "✅ Dart found: $(dart --version 2>&1)"

# Get current directory
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "📁 Project directory: $CURRENT_DIR"

# Install dependencies
echo "📦 Installing dependencies..."
dart pub get

# Determine shell config file
if [ "$SHELL" = "/bin/zsh" ] || [ "$SHELL" = "/usr/bin/zsh" ]; then
    SHELL_CONFIG="$HOME/.zprofile"
elif [ "$SHELL" = "/bin/bash" ] || [ "$SHELL" = "/usr/bin/bash" ]; then
    SHELL_CONFIG="$HOME/.bash_profile"
else
    SHELL_CONFIG="$HOME/.profile"
fi

# Check for GEMINI_API_KEY
if [ -z "$GEMINI_API_KEY" ]; then
    echo "🔑 Setting up Gemini API key..."
    echo "   Get your token at: https://aistudio.google.com/apikey"
    echo ""
    echo -n "Please enter your Gemini API key (hidden): "
    read -s api_token
    echo "********"
    
    if [ -n "$api_token" ]; then
        # Add to shell profile
        echo "export GEMINI_API_KEY=\"$api_token\"" >> "$SHELL_CONFIG"
        echo "✅ Key saved to $SHELL_CONFIG"
        export GEMINI_API_KEY="$api_token"
        # Source the file to load the variable immediately
        source "$SHELL_CONFIG"
    else
        echo "⚠️  No key provided. You can set it later by adding:"
        echo "   export GEMINI_API_KEY=your_key_here"
        echo "   to your $SHELL_CONFIG"
    fi
else
    echo "✅ GEMINI_API_KEY is set"
fi

# Create alias
ALIAS_LINE="alias translator='dart $CURRENT_DIR/bin/translator.dart'"

if grep -q "alias translator=" "$SHELL_CONFIG" 2>/dev/null; then
    echo "✅ Translator alias already exists in $SHELL_CONFIG"
else
    echo "🔗 Adding translator alias to $SHELL_CONFIG..."
    echo "$ALIAS_LINE" >> "$SHELL_CONFIG"
    echo "✅ Alias added successfully"
fi

echo ""
echo "🎉 Setup completed!"
echo ""
echo "Next steps:"
echo "1. Reload your shell configuration:"
echo "   source $SHELL_CONFIG"
echo ""
echo "2. Set your GEMINI_API_KEY if not already set:"
echo "   export GEMINI_API_KEY=your_key_here"
echo ""
echo "3. Test the installation:"
echo "   translator --help"