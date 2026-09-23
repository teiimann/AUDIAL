#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/.build/AUDIAL.app"
codesign --verify --strict "$APP"
mkdir -p dist
STAGING=$(mktemp -d "$PWD/.build/audial-package.XXXXXX")
ditto "$APP" "$STAGING/AUDIAL.app"
cp docs/TESTING-RU.txt "$STAGING/ПРОЧИТАЙ.txt"
ditto -c -k --sequesterRsrc "$STAGING" "$PWD/dist/AUDIAL-0.2.0-universal.zip"
# Staging is generated exclusively by this script.
rm -rf "$STAGING"
shasum -a 256 dist/AUDIAL-0.2.0-universal.zip > dist/AUDIAL-0.2.0-universal.sha256
