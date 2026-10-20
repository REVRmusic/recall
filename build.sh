#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "🎵 Compilation de Recall en mode Release..."
swift build -c release

APP_NAME="Recall"
BUILD_DIR="$DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Création du bundle $APP_NAME.app..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

if [ -f "$DIR/Resources/AppIcon.icns" ]; then
    cp "$DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi
if [ -f "$DIR/Resources/AppIcon.png" ]; then
    cp "$DIR/Resources/AppIcon.png" "$RESOURCES_DIR/AppIcon.png"
fi
for icon_variant in "$DIR/Resources/AppIcon_"*.png; do
    if [ -f "$icon_variant" ]; then
        cp "$icon_variant" "$RESOURCES_DIR/"
    fi
done

# Copie du binaire compilé
BIN_DIR="$(swift build --show-bin-path -c release)"
if [ -f "$BIN_DIR/Recall" ]; then
    cp "$BIN_DIR/Recall" "$MACOS_DIR/$APP_NAME"
elif [ -f "$DIR/.build/release/Recall" ]; then
    cp "$DIR/.build/release/Recall" "$MACOS_DIR/$APP_NAME"
fi
chmod +x "$MACOS_DIR/$APP_NAME"

# Création du Info.plist
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>fr</string>
    <key>CFBundleExecutable</key>
    <string>Recall</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>fr.revr.recall</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Recall</string>
    <key>CFBundleDisplayName</key>
    <string>Recall</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.10</string>
    <key>CFBundleVersion</key>
    <string>1.0.10</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSPhotoLibraryAddUsageDescription</key>
    <string>Recall nécessite l'accès à Photos pour enregistrer directement le récapitulatif visuel de votre mix.</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>Recall nécessite l'accès à Photos pour enregistrer directement le récapitulatif visuel de votre mix.</string>
</dict>
</plist>
EOF

# PkgInfo
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Nettoyage des attributs étendus et signature ad-hoc propre du bundle complet pour TCC et Accessibilité macOS
echo "🔏 Signature de $APP_NAME.app avec designated requirement stable..."
xattr -cr "$APP_BUNDLE" 2>/dev/null || true
codesign --force --deep --sign - --identifier "fr.revr.recall" -r='designated => identifier "fr.revr.recall"' "$APP_BUNDLE"

# Installation optionnelle dans /Applications
rm -rf /Applications/Recall.app 2>/dev/null || true
cp -R "$APP_BUNDLE" /Applications/Recall.app 2>/dev/null || true
xattr -cr /Applications/Recall.app 2>/dev/null || true
codesign --force --deep --sign - --identifier "fr.revr.recall" -r='designated => identifier "fr.revr.recall"' /Applications/Recall.app

echo "✅ Recall.app créé avec succès dans :"
echo "   $APP_BUNDLE"

if [ "$1" == "--dmg" ] || [ "$BUILD_DMG" == "1" ]; then
    echo "💿 Création de l'image disque Recall.dmg..."
    DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
    DMG_TEMP=$(mktemp -d)
    cp -R "$APP_BUNDLE" "$DMG_TEMP/"
    ln -s /Applications "$DMG_TEMP/Applications"
    rm -f "$DMG_PATH"
    hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_TEMP" -ov -format UDZO "$DMG_PATH" > /dev/null
    rm -rf "$DMG_TEMP"
    echo "✅ Image disque prête :"
    echo "   $DMG_PATH"
    
    echo "📦 Création de l'archive Recall-macOS.zip..."
    (cd "$BUILD_DIR" && rm -f "Recall-macOS.zip" && ditto -c -k --keepParent "$APP_NAME.app" "Recall-macOS.zip")
    echo "✅ Archive Recall-macOS.zip prête."
fi
