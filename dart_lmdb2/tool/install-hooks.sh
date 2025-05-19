#!/bin/bash

# Install git hooks for dart_lmdb2

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
# Look for .git directory up to 3 levels up
for i in 1 2 3; do
    CHECK_DIR="$PROJECT_ROOT"
    for j in $(seq 1 $i); do
        CHECK_DIR=$(dirname "$CHECK_DIR")
    done
    if [ -d "$CHECK_DIR/.git" ]; then
        GIT_DIR="$CHECK_DIR/.git"
        break
    fi
done

if [ -z "$GIT_DIR" ]; then
    GIT_DIR="$PROJECT_ROOT/.git"
fi
HOOKS_SOURCE_DIR="$SCRIPT_DIR/git-hooks"
HOOKS_TARGET_DIR="$GIT_DIR/hooks"

if [ ! -d "$GIT_DIR" ]; then
    echo "Error: Not in a git repository"
    exit 1
fi

echo "Installing git hooks..."

# Create hooks directory if it doesn't exist
mkdir -p "$HOOKS_TARGET_DIR"

# Install pre-commit hook
if [ -f "$HOOKS_SOURCE_DIR/pre-commit" ]; then
    cp "$HOOKS_SOURCE_DIR/pre-commit" "$HOOKS_TARGET_DIR/pre-commit"
    chmod +x "$HOOKS_TARGET_DIR/pre-commit"
    echo "Installed pre-commit hook"
else
    echo "Error: pre-commit hook not found in $HOOKS_SOURCE_DIR"
    exit 1
fi

echo "Git hooks installation complete!"
echo "The pre-commit hook will automatically update version.dart when pubspec.yaml changes."