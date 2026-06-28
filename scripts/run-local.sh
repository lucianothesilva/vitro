#!/bin/sh
# Builda o Vitro em Release e instala em /Applications para uso local.
# Ad-hoc signing basta nesta máquina — sem necessidade de notarização.
set -e
cd "$(dirname "$0")/.."

xcodebuild -project Vitro.xcodeproj -scheme Vitro -configuration Release \
  -derivedDataPath build/xcode build

APP="build/xcode/Build/Products/Release/Vitro.app"

# Fecha instância em execução, se houver.
pkill -f "Vitro.app/Contents/MacOS/Vitro" 2>/dev/null || true

rm -rf /Applications/Vitro.app
cp -R "$APP" /Applications/
open -a Vitro
echo "Vitro instalado em /Applications e aberto."
