@echo off
setlocal EnableExtensions EnableDelayedExpansion

cd /d "%~dp0\.."
set "PROJECT_ROOT=%CD%"
set "PUBSPEC=%PROJECT_ROOT%\pubspec.yaml"
set "SCRIPT=%PROJECT_ROOT%\installer\members_inno2.iss"

if not exist "%PUBSPEC%" (
  echo [ERROR] pubspec.yaml not found: %PUBSPEC%
  exit /b 1
)

if not exist "%SCRIPT%" (
  echo [ERROR] Inno script not found: %SCRIPT%
  exit /b 1
)

where flutter.bat >nul 2>&1
if errorlevel 1 (
  echo [ERROR] flutter.bat is not in PATH.
  exit /b 1
)

set "ISCC=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" set "ISCC=C:\Program Files\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" (
  echo [ERROR] ISCC.exe not found. Install Inno Setup 6 first.
  exit /b 1
)

set "RAW_VERSION="
for /f "tokens=2 delims=: " %%A in ('findstr /b /c:"version:" "%PUBSPEC%"') do (
  set "RAW_VERSION=%%A"
)

if not defined RAW_VERSION (
  echo [ERROR] Could not read version from pubspec.yaml.
  exit /b 1
)

set "RAW_VERSION=%RAW_VERSION:"=%"
for /f "tokens=1,2 delims=+" %%A in ("%RAW_VERSION%") do (
  set "VER_NAME=%%A"
  set "VER_BUILD=%%B"
)
if not defined VER_BUILD set "VER_BUILD=0"
set "INNO_VERSION=%VER_NAME%.%VER_BUILD%"

echo [1/2] Building Windows release...
call flutter.bat build windows --release
if errorlevel 1 (
  echo [ERROR] Flutter build failed.
  exit /b 1
)

echo [2/2] Building installer version %INNO_VERSION%...
"%ISCC%" /DMyAppVersion=%INNO_VERSION% "%SCRIPT%"
if errorlevel 1 (
  echo [ERROR] Inno compile failed.
  exit /b 1
)

echo [DONE] Installer created in build\windows\installer
exit /b 0
