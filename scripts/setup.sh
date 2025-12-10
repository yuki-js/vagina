#!/bin/bash
# Setup script for VAGINA development environment
# Run: ./scripts/setup.sh

set -e

echo "Setting up VAGINA development environment..."

# Check if fvm is available
if ! command -v fvm &> /dev/null; then
    echo "Warning: fvm is not installed. Please install fvm first."
    echo "See: https://fvm.app/docs/getting_started/installation"
    exit 1
fi

# Install git hooks
echo "Installing pre-commit hook..."
chmod +x scripts/pre-commit.sh
cp scripts/pre-commit.sh .git/hooks/pre-commit

# Install Flutter dependencies using fvm
echo "Installing Flutter dependencies..."
if ! fvm flutter pub get; then
    echo "Error: Failed to install Flutter dependencies."
    exit 1
fi

echo "Setup complete!"
echo ""
echo "Development tools installed:"
echo "  - Pre-commit hook (format & analyze)"
if fvm flutter --version &> /dev/null; then
    echo "  - Flutter version: $(fvm flutter --version | head -n 1)"
fi
echo ""
echo "Run 'fvm flutter run' to start the app."
