#!/usr/bin/env bash
# Descarga yt-dlp (GitHub) y copia ffmpeg (Homebrew) a Resources/
# Corré esto UNA VEZ antes del primer build.
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p Resources

# ──────────────────────────────────────────────
# yt-dlp — binary universal macOS desde GitHub
# ──────────────────────────────────────────────
echo "→ Descargando yt-dlp (última versión)..."
curl -fsSL \
    "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos" \
    -o Resources/yt-dlp
chmod +x Resources/yt-dlp
echo "  $(Resources/yt-dlp --version 2>/dev/null || echo 'instalado')"

# ──────────────────────────────────────────────
# ffmpeg — copia desde Homebrew (arm64)
# ──────────────────────────────────────────────
echo "→ Copiando ffmpeg desde Homebrew..."
FFMPEG_BIN=""
for candidate in /opt/homebrew/bin/ffmpeg /usr/local/bin/ffmpeg; do
    if [ -x "$candidate" ]; then
        FFMPEG_BIN="$candidate"
        break
    fi
done

if [ -z "$FFMPEG_BIN" ]; then
    echo "✗  ffmpeg no encontrado. Instalalo con:"
    echo "   brew install ffmpeg"
    echo ""
    echo "   Alternativa: descargalo de https://evermeet.cx/ffmpeg/"
    echo "   y copialo manualmente a Resources/ffmpeg"
    exit 1
fi

cp "$FFMPEG_BIN" Resources/ffmpeg
chmod +x Resources/ffmpeg
echo "  copiado desde $FFMPEG_BIN"

echo ""
echo "✓  Resources/yt-dlp y Resources/ffmpeg listos."
