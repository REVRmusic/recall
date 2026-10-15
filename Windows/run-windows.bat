@echo off
chcp 65001 >nul
cd /d "%~dp0"

if exist "build-win\Recall.exe" (
    echo Démarrage de Recall...
    start "" "build-win\Recall.exe"
) else (
    echo Compilation préalable ou lancement via dotnet...
    dotnet run --project Recall\Recall.csproj
)
