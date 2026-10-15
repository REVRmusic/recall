@echo off
chcp 65001 >nul
echo ========================================================
echo   Compilation de Recall pour Windows (.NET 8 WPF x64)
echo ========================================================
cd /d "%~dp0"

where dotnet >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERREUR] Le SDK .NET 8 n'est pas installé sur ce PC.
    echo Téléchargez-le gratuitement sur : https://dotnet.microsoft.com/download/dotnet/8.0
    pause
    exit /b 1
)

echo [1/2] Restauration des paquets NuGet...
dotnet restore Recall.sln

echo [2/2] Compilation en mode Release autonome (Self-Contained Single-File)...
dotnet publish Recall\Recall.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true -o build-win

echo.
echo ========================================================
echo   ✅ Compilation terminée avec succès !
echo   Exécutable autonome prêt : Windows\build-win\Recall.exe
echo ========================================================
pause
