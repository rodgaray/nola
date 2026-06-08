#!/usr/bin/env bash
# build.sh — genera, compila en Release y firma ad-hoc NoLa.app
set -euo pipefail

APP_NAME="NoLa"
SCHEME="NoLa"
PROJECT="${APP_NAME}.xcodeproj"
APP_PATH=".build/Build/Products/Release/${APP_NAME}.app"

# Aviso si faltan los binarios bundleados (no es fatal — usará Homebrew)
if [ ! -f "Resources/yt-dlp" ] || [ ! -f "Resources/ffmpeg" ]; then
    echo "⚠  Resources/yt-dlp y/o Resources/ffmpeg no encontrados."
    echo "   La app usará los binarios de Homebrew como fallback."
    echo "   Para bundlear: ./scripts/download-deps.sh"
    echo ""
fi

# 1. Generar .xcodeproj
echo "→ xcodegen generate..."
/opt/homebrew/bin/xcodegen generate

# 2. Compilar en Release
echo "→ xcodebuild Release (arm64)..."
BUILD_LOG=$(xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -arch arm64 \
    -derivedDataPath .build \
    AD_HOC_CODE_SIGNING_ALLOWED=YES \
    ONLY_ACTIVE_ARCH=YES \
    build 2>&1)

# Mostrar errores y resultado final
echo "$BUILD_LOG" | grep -E "error:|^ *\*\* BUILD" | grep -v IDESimulator || true
if echo "$BUILD_LOG" | grep -q "BUILD FAILED"; then
    echo ""
    echo "--- Log completo ---"
    echo "$BUILD_LOG"
    exit 1
fi

# 3. Firmar los binarios bundleados dentro del .app
for bin in yt-dlp ffmpeg; do
    NESTED="${APP_PATH}/Contents/Resources/${bin}"
    if [ -f "$NESTED" ]; then
        echo "→ Firmando ${bin}..."
        codesign --force --sign - "$NESTED"
    fi
done

# 4. Firmar el bundle completo (ad-hoc, sin notarización)
echo "→ Firmando ${APP_NAME}.app (ad-hoc)..."
codesign --force --deep --sign - "$APP_PATH"

echo ""
echo "✓  Build completo"
echo "   App: ${APP_PATH}"
echo "   Abrí con: open '${APP_PATH}'"
