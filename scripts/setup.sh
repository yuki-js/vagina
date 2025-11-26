#!/bin/bash
# Setup script for VAGINA development environment
# Run: ./scripts/setup.sh

set -e

echo "Setting up VAGINA development environment..."

# Install git hooks
echo "Installing pre-commit hook..."
chmod +x scripts/pre-commit.sh
cp scripts/pre-commit.sh .git/hooks/pre-commit

# Install Flutter dependencies
echo "Installing Flutter dependencies..."
flutter pub get

echo "Setup complete!"
echo ""
echo "Development tools installed:"
echo "  - Pre-commit hook (format & analyze)"
echo ""
echo "Run 'flutter run' to start the app."
