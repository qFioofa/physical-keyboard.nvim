#!/bin/bash

# In lazy cofig insert line from `in_lazy.lua`

PLUGIN_NAME="physical-keyboard.nvim"
TARGET_DIR="$HOME/.config/nvim/lazy/$PLUGIN_NAME"

# Проверяем аргументы
REMOVE_OLD=0
for arg in "$@"; do
  if [ "$arg" = "-r" ]; then
    REMOVE_OLD=1
  fi
done

if [ $REMOVE_OLD -eq 1 ]; then
  echo "Removing old version..."
  rm -rf "$TARGET_DIR"
fi

if [ ! -d "./lua" ]; then
  echo "ERROR: lua/ folder not found in current directory."
  exit 1
fi

mkdir -p "$TARGET_DIR"

cp -r lua "$TARGET_DIR/"
cp -r plugin "$TARGET_DIR/" 2>/dev/null && echo "Copied plugin/"
cp -r README.md "$TARGET_DIR/" 2>/dev/null && echo "Copied README.md"
cp -r .gitignore "$TARGET_DIR/" 2>/dev/null && echo "Copied .gitignore"
cp -r stylua.toml "$TARGET_DIR/" 2>/dev/null && echo "Copied stylua.toml"

echo "Deployed to $TARGET_DIR"
