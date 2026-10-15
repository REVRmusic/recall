#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

# Construction de l'application si nécessaire
if [ ! -d "$DIR/build/Recall.app" ]; then
    bash "$DIR/build.sh"
fi

echo "🚀 Lancement de Recall..."
open "$DIR/build/Recall.app"
