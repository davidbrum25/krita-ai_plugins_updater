#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"

echo "Instalando Update Krita AI Tools..."

mkdir -p "$BIN_DIR" "$APP_DIR"

# Instalar ejecutable
install -m 755 "$SCRIPT_DIR/actualizar_plugins.sh" "$BIN_DIR/update-krita-ai-tools"

# Instalar acceso directo de escritorio ajustando la ruta al HOME actual
sed "s|/home/david|$HOME|g" "$SCRIPT_DIR/update-krita-ai-tools.desktop" > "$APP_DIR/update-krita-ai-tools.desktop"
chmod 755 "$APP_DIR/update-krita-ai-tools.desktop"

# Actualizar base de datos de escritorio y caché de KDE Plasma si existen
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$APP_DIR" 2>/dev/null || true
fi
if command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
fi

echo "✅ Instalación completa:"
echo "   - Binario:  $BIN_DIR/update-krita-ai-tools"
echo "   - Launcher: $APP_DIR/update-krita-ai-tools.desktop"
echo ""
echo "Ya puedes ejecutar 'update-krita-ai-tools' desde la terminal o buscar 'Update Krita AI Tools' en el lanzador de aplicaciones de KDE Plasma (Kickoff / KRunner)."
