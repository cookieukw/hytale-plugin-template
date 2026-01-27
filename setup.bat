@echo off
setlocal EnableDelayedExpansion

if not exist "files" (
    echo Error: 'files' directory not found.
    exit /b 1
)

echo Welcome to the Project Setup Script
echo -----------------------------------

set /p PROJECT_NAME="Enter Project Name (e.g., MyPlugin): "
set /p AUTHOR_NAME="Enter Author Name: "
set /p WEBSITE_URL="Enter Website URL: "
set /p PACKAGE_NAME="Enter Package Name (e.g., com.example.myplugin): "

if "%PROJECT_NAME%"=="" (
    echo Error: Project Name is required.
    exit /b 1
)
if "%PACKAGE_NAME%"=="" (
    echo Error: Package Name is required.
    exit /b 1
)

echo Updating Gradle configurations...
powershell -Command "(Get-Content settings.gradle) -replace \"rootProject.name = 'ExamplePlugin'\", \"rootProject.name = '%PROJECT_NAME%'\" | Set-Content settings.gradle"
powershell -Command "(Get-Content build.gradle) -replace \"group = 'com.cookie.test'\", \"group = '%PACKAGE_NAME%'\" | Set-Content build.gradle"

echo Creating resources...
if not exist "src\main\resources" mkdir "src\main\resources"
if not exist "libs" mkdir "libs"
if exist "files\manifest.json" copy "files\manifest.json" "src\main\resources\"

set /p PROJECT_VERSION="Enter Project Version (default: 1.0.0): "
if "%PROJECT_VERSION%"=="" set PROJECT_VERSION=1.0.0

echo Updating manifest.json...
:: Use regex replacement on the COPIED file in src, NOT files/
powershell -Command ^
    "$path = 'src/main/resources/manifest.json'; " ^
    "$content = Get-Content $path -Raw; " ^
    "$content = $content -replace '\"Group\": \".*\"', '\"Group\": \"%PACKAGE_NAME%\"'; " ^
    "$content = $content -replace '  \"Name\": \".*\"', '  \"Name\": \"%PROJECT_NAME%\"'; " ^
    "$content = $content -replace '  \"Version\": \".*\"', '  \"Version\": \"%PROJECT_VERSION%\"'; " ^
    "$content = $content -replace '      \"Name\": \".*\"', '      \"Name\": \"%AUTHOR_NAME%\"'; " ^
    "$content = $content -replace '\"Url\": \".*\"', '\"Url\": \"%WEBSITE_URL%\"'; " ^
    "$content = $content -replace '\"Website\": \".*\"', '\"Website\": \"%WEBSITE_URL%\"'; " ^
    "$content = $content -replace '\"Main\": \"com.cookie.test', '\"Main\": \"%PACKAGE_NAME%'; " ^
    "Set-Content $path $content"

echo Refactoring and moving Java files...
:: PowerShell script to handle file processing with correct subpackage preservation
powershell -Command ^
    "$packageName = '%PACKAGE_NAME%'; " ^
    "$oldPackage = 'com.cookie.test'; " ^
    "Get-ChildItem -Path 'files' -Filter '*.java' -Recurse | ForEach-Object { " ^
    "   $content = Get-Content $_.FullName -Raw; " ^
    "   $originalPkgLine = $content -split \"`r`n\" | Select-String -Pattern '^package\s+([\w\.]+);' | Select-Object -First 1; " ^
    "   if ($originalPkgLine) { " ^
    "       $originalPkg = $originalPkgLine.Matches.Groups[1].Value; " ^
    "       " ^
    "       if ($originalPkg.StartsWith($oldPackage)) { " ^
    "           $newPkg = $originalPkg.Replace($oldPackage, $packageName); " ^
    "       } else { " ^
    "           $newPkg = $packageName; " ^
    "       } " ^
    "       " ^
    "       $path = 'src/main/java/' + $newPkg.Replace('.', '/'); " ^
    "       New-Item -ItemType Directory -Force -Path $path | Out-Null; " ^
    "       " ^
    "       $destFile = Join-Path $path $_.Name; " ^
    "       " ^
    "       $content = $content -replace \"package $oldPackage\", \"package $packageName\"; " ^
    "       $content = $content -replace \"import $oldPackage\", \"import $packageName\"; " ^
    "       " ^
    "       Set-Content -Path $destFile -Value $content; " ^
    "       Write-Host \"Created $destFile\"; " ^
    "   } " ^
    "}"

echo Running Gradle build...
if exist "gradlew.bat" (
    call gradlew.bat build
) else (
    echo Error: Gradle wrapper 'gradlew.bat' not found.
    echo Please ensure you are running this script from the project root.
    exit /b 1
)

echo Setup complete. JAR file should be in dist/
pause
