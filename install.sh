#!/bin/bash
set -e

# Recall - Script d'installation automatique pour macOS
# https://github.com/REVRmusic/recall

APP_NAME="Recall"
INSTALL_DIR="/Applications"
TARGET_APP="$INSTALL_DIR/$APP_NAME.app"
REPO_URL="https://github.com/REVRmusic/recall"
RELEASE_DMG_URL="$REPO_URL/releases/latest/download/Recall.dmg"

echo "==============================================="
echo "🎧 Installation de Recall pour Serato DJ Pro"
echo "==============================================="

# Vérification macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Erreur : Recall est uniquement compatible avec macOS (13.0+)."
    exit 1
fi

TEMP_DIR=$(mktemp -d)
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo "⬇️  Téléchargement de la dernière version..."

DMG_FILE="$TEMP_DIR/Recall.dmg"
HTTP_STATUS=$(curl -sL -w "%{http_code}" -o "$DMG_FILE" "$RELEASE_DMG_URL" || true)

if [ "$HTTP_STATUS" != "200" ] || [ ! -s "$DMG_FILE" ]; then
    echo "⚠️  L'image disque précompilée n'est pas encore disponible sur GitHub Releases."
    echo "🔄 Tentative de compilation locale via Swift..."
    
    if ! command -v swift &> /dev/null; then
        echo "❌ Swift n'est pas installé. Veuillez installer Xcode Command Line Tools via : xcode-select --install"
        exit 1
    fi
    
    CLONE_DIR="$TEMP_DIR/recall-source"
    git clone --depth 1 "$REPO_URL.git" "$CLONE_DIR"
    cd "$CLONE_DIR"
    chmod +x build.sh
    ./build.sh
    
    echo "✅ Recall.app a été compilé et installé avec succès dans /Applications !"
else
    echo "📦 Montage de l'image disque..."
    MOUNT_POINT=$(mktemp -d)
    hdiutil attach "$DMG_FILE" -mountpoint "$MOUNT_POINT" -nobrowse -quiet
    
    echo "🔄 Fermeture de l'ancienne version si elle est ouverte..."
    killall "$APP_NAME" 2>/dev/null || true
    sleep 0.5
    
    echo "🚀 Installation de $APP_NAME.app dans $INSTALL_DIR..."
    rm -rf "$TARGET_APP" 2>/dev/null || true
    /usr/bin/ditto "$MOUNT_POINT/$APP_NAME.app" "$TARGET_APP"
    
    hdiutil detach "$MOUNT_POINT" -quiet -force 2>/dev/null || true
    rm -rf "$MOUNT_POINT"
    
    # Suppression intégrale de l'attribut de quarantaine Gatekeeper et signature ad-hoc stable
    /usr/bin/xattr -cr "$TARGET_APP" 2>/dev/null || true
    /bin/chmod +x "$TARGET_APP/Contents/MacOS/$APP_NAME" 2>/dev/null || true
    /usr/bin/codesign --force --deep --sign - --identifier "fr.revr.recall" -r='designated => identifier "fr.revr.recall"' "$TARGET_APP" 2>/dev/null || true
    
    echo ""
    echo "==============================================="
    echo "✅ $APP_NAME a été installé et validé avec succès dans :"
    echo "   $TARGET_APP"
    echo "==============================================="
    echo "🚀 Lancement automatique de Recall..."
    /usr/bin/open -n "$TARGET_APP" 2>/dev/null || true
fi
