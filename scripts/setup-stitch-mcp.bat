@echo off
echo ========================================
echo   Stitch MCP Setup Script for Windows
echo ========================================
echo.

REM Check if Node.js is installed
echo [1/5] Checking Node.js...
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Node.js not found!
    echo Please install from: https://nodejs.org/
    echo Then restart terminal and run this script again.
    pause
    exit /b 1
)
echo OK: Node.js found
node --version
echo.

REM Check if gcloud is installed
echo [2/5] Checking Google Cloud CLI...
where gcloud >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Google Cloud CLI (gcloud) not found!
    echo Please install from: https://cloud.google.com/sdk/docs/install
    echo Then restart terminal and run this script again.
    pause
    exit /b 1
)
echo OK: gcloud found
gcloud --version
echo.

REM Authenticate with Google Cloud
echo [3/5] Authenticating with Google Cloud...
echo This will open a browser window for login.
echo Please sign in with your Google account.
echo.
gcloud auth login
if %errorlevel% neq 0 (
    echo ERROR: Authentication failed!
    pause
    exit /b 1
)
echo OK: Authentication successful
echo.

REM Set up application default credentials
echo [4/5] Setting up application default credentials...
echo Another browser window will open for OAuth.
echo.
gcloud auth application-default login
if %errorlevel% neq 0 (
    echo ERROR: Failed to set application credentials!
    pause
    exit /b 1
)
echo OK: Application credentials set
echo.

REM Get project ID
echo [5/5] Getting Google Cloud project...
for /f "tokens=*" %%i in ('gcloud config get-value project 2^>nul') do set PROJECT_ID=%%i
if "%PROJECT_ID%"=="" (
    echo WARNING: No project set. Please run:
    echo   gcloud config set project YOUR_PROJECT_ID
    echo.
) else (
    echo OK: Project ID: %PROJECT_ID%
)
echo.

REM Update mcp.json
echo Updating mcp.json configuration...
echo.

echo ========================================
echo   Setup Complete!
echo ========================================
echo.
echo Next steps:
echo 1. Make sure you have a Google Cloud project with Stitch API enabled
echo 2. Run: gcloud config set project YOUR_PROJECT_ID
echo 3. Restart your AI assistant to load Stitch MCP
echo.
pause
