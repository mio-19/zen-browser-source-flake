#!/bin/sh
set -euxo pipefail
nix flake update
RELEASE_TAG=$(curl -s https://api.github.com/repos/zen-browser/desktop/releases/latest | jq -r .tag_name)
curl -sL "https://raw.githubusercontent.com/zen-browser/desktop/refs/tags/${RELEASE_TAG}/surfer.json" -o surfer.json
FIREFOX_VERSION=$(jq -r '.version.version' surfer.json)
sed -i "18s/version = \".*\";/version = \"${RELEASE_TAG}\";/" flake.nix
sed -i "19s/firefoxVersion = \".*\";/firefoxVersion = \"${FIREFOX_VERSION}\";/" flake.nix