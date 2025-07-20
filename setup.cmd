@echo off
setlocal enabledelayedexpansion

echo 🚀 Setting up Translator App...

REM Check if Dart is installed
dart --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Dart is not installed. Please install Dart first:
    echo    Visit: https://dartbrasil.dev/get-dart
    pause
    exit /b 1
)

echo ✅ Dart found:
dart --version

REM Get current directory
set "CURRENT_DIR=%~dp0"
set "CURRENT_DIR=%CURRENT_DIR:~0,-1%"
echo 📁 Project directory: %CURRENT_DIR%

REM Install dependencies
echo 📦 Installing dependencies...
dart pub get
if %errorlevel% neq 0 (
    echo ❌ Failed to install dependencies
    pause
    exit /b 1
)

REM Check for GEMINI_API_KEY
if "%GEMINI_API_KEY%"=="" (
    echo 🔑 Setting up Gemini API key...
    echo    Get your token at: https://aistudio.google.com/apikey
    echo.
    set /p api_token="Please enter your Gemini API key: "
    
    if not "!api_token!"=="" (
        setx GEMINI_API_KEY "!api_token!"
        echo ✅ Key saved as environment variable
        set "GEMINI_API_KEY=!api_token!"
    ) else (
        echo ⚠️  No key provided. You can set it later by running:
        echo    setx GEMINI_API_KEY "your_key_here"
    )
) else (
    echo ✅ GEMINI_API_KEY is set
)

REM Create batch file for translator command
set "BATCH_FILE=%CURRENT_DIR%\translator.bat"
echo Creating translator.bat...
(
    echo @echo off
    echo dart "%CURRENT_DIR%\bin\translator.dart" %%*
) > "%BATCH_FILE%"

if exist "%BATCH_FILE%" (
    echo ✅ translator.bat created successfully
) else (
    echo ❌ Failed to create translator.bat
    pause
    exit /b 1
)

REM Check if current directory is in PATH
echo %PATH% | findstr /I /C:"%CURRENT_DIR%" >nul
if %errorlevel% neq 0 (
    echo 🔗 Adding project directory to PATH...
    setx PATH "%PATH%;%CURRENT_DIR%"
    echo ✅ PATH updated successfully
    echo    Please restart your command prompt for PATH changes to take effect.
) else (
    echo ✅ Project directory already in PATH
)

echo.
echo 🎉 Setup completed!
echo.
echo Next steps:
echo 1. Restart your command prompt to apply PATH changes
echo.
echo 2. Set your GEMINI_TOKEN if not already set:
echo    setx GEMINI_TOKEN "your_token_here"
echo.
echo 3. Test the installation:
echo    translator --help
echo.
pause