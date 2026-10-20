#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

APP_NAME="Recall"
BUILD_DIR="$DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
FINAL_DMG="$BUILD_DIR/$APP_NAME.dmg"
RW_DMG="$BUILD_DIR/${APP_NAME}_rw.dmg"
VOL_NAME="Recall"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ Erreur : $APP_BUNDLE introuvable. Exécutez d'abord ./build.sh"
    exit 1
fi

echo "🎨 Vérification / génération des visuels d'arrière-plan du DMG..."
python3 "$DIR/scripts/generate_dmg_background.py"

# Calcul de la taille nécessaire (taille de l'app + 60 Mo de marge)
APP_SIZE_MB=$(du -sm "$APP_BUNDLE" | awk '{print $1}')
DMG_SIZE_MB=$(( APP_SIZE_MB + 60 ))
if [ "$DMG_SIZE_MB" -lt 180 ]; then
    DMG_SIZE_MB=180
fi

echo "💿 Création de l'image disque temporaire (${DMG_SIZE_MB} Mo)..."
rm -f "$RW_DMG" "$FINAL_DMG"
hdiutil create -size "${DMG_SIZE_MB}m" -fs HFS+ -volname "$VOL_NAME" -type UDIF "$RW_DMG" -ov > /dev/null

echo "📂 Montage de l'image de travail..."
# Montage
MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG")
DEV_NAME=$(echo "$MOUNT_OUTPUT" | grep -E '^/dev/' | head -n 1 | awk '{print $1}')
MOUNT_DIR="/Volumes/$VOL_NAME"

# Attendre que le volume soit bien accessible
for i in {1..10}; do
    if [ -d "$MOUNT_DIR" ]; then
        break
    fi
    sleep 0.5
done

if [ ! -d "$MOUNT_DIR" ]; then
    echo "❌ Échec du montage du volume dans $MOUNT_DIR"
    exit 1
fi

echo "🚀 Copie de $APP_NAME.app et création du lien Applications..."
cp -R "$APP_BUNDLE" "$MOUNT_DIR/"
ln -s /Applications "$MOUNT_DIR/Applications"

# Dossier d'arrière-plan caché
mkdir -p "$MOUNT_DIR/.background"
cp "$DIR/Resources/dmg_background.png" "$MOUNT_DIR/.background/background.png"
if [ -f "$DIR/Resources/dmg_background@2x.png" ]; then
    cp "$DIR/Resources/dmg_background@2x.png" "$MOUNT_DIR/.background/background@2x.png"
fi

# Icône du volume
if [ -f "$DIR/Resources/AppIcon.icns" ]; then
    cp "$DIR/Resources/AppIcon.icns" "$MOUNT_DIR/.VolumeIcon.icns"
    if [ -x "/usr/bin/SetFile" ]; then
        /usr/bin/SetFile -c icnC "$MOUNT_DIR/.VolumeIcon.icns" 2>/dev/null || true
        /usr/bin/SetFile -a C "$MOUNT_DIR" 2>/dev/null || true
    fi
fi

# Configuration visuelle du Finder via AppleScript
echo "📐 Configuration de l'affichage Finder (arrière-plan, taille et disposition des icônes)..."
osascript << EOF 2>/dev/null || echo "⚠️ Avertissement : Finder AppleScript non exécuté dans cet environnement."
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        -- Largeur 660, Hauteur 450 (laisse respirer le badge inférieur sous les icônes)
        set the bounds of container window to {300, 120, 960, 570}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set background picture of viewOptions to file ".background:background.png"
        -- Position Recall.app à gauche (x=175, y=190)
        set position of item "$APP_NAME.app" of container window to {175, 190}
        -- Position dossier Applications à droite (x=485, y=190)
        set position of item "Applications" of container window to {485, 190}
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

# Nettoyage et synchronisation du système de fichiers
sync
sync
sleep 1

# Démontage
echo "🔒 Finalisation et compression de l'image disque..."
hdiutil detach "$DEV_NAME" -quiet -force || hdiutil detach "$MOUNT_DIR" -quiet -force 2>/dev/null || true
sleep 1

# Conversion en image finale compressée en lecture seule UDZO
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" -ov > /dev/null
rm -f "$RW_DMG"

echo "=========================================================="
echo "✨ Image disque professionnelle prête avec succès :"
echo "   $FINAL_DMG ($(du -h "$FINAL_DMG" | awk '{print $1}'))"
echo "=========================================================="
