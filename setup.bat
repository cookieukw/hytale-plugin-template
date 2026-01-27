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

echo Updating manifest.json...
:: Use regex replacement instead of JSON parsing to preserve formatting, matching setup.sh logic
powershell -Command ^
    "$path = 'files/manifest.json'; " ^
    "$content = Get-Content $path -Raw; " ^
    "$content = $content -replace '\"Group\": \".*\"', '\"Group\": \"%PACKAGE_NAME%\"'; " ^
    "$content = $content -replace '  \"Name\": \".*\"', '  \"Name\": \"%PROJECT_NAME%\"'; " ^
    "$content = $content -replace '      \"Name\": \".*\"', '      \"Name\": \"%AUTHOR_NAME%\"'; " ^
    "$content = $content -replace '\"Url\": \".*\"', '\"Url\": \"%WEBSITE_URL%\"'; " ^
    "$content = $content -replace '\"Website\": \".*\"', '\"Website\": \"%WEBSITE_URL%\"'; " ^
    "Set-Content $path $content"

echo Creating resources...
if not exist "src\main\resources" mkdir "src\main\resources"
if exist "files\manifest.json" copy "files\manifest.json" "src\main\resources\"

echo Refactoring and moving Java files...
:: PowerShell script to handle file processing
powershell -Command ^
    "$packageName = '%PACKAGE_NAME%'; " ^
    "$oldPackage = 'com.cookie.test'; " ^
    "Get-ChildItem -Path 'files' -Filter '*.java' -Recurse | ForEach-Object { " ^
    "   $content = Get-Content $_.FullName -Raw; " ^
    "   $content = $content -replace \"package .*\", \"package $packageName;\"; " ^
    "   $content = $content -replace \"import $oldPackage\", \"import $packageName\"; " ^
    "   Set-Content -Path $_.FullName -Value $content; " ^
    "   $fullPkg = $packageName; " ^
    "   $path = 'src/main/java/' + $fullPkg.Replace('.', '/'); " ^
    "   New-Item -ItemType Directory -Force -Path $path | Out-Null; " ^
    "   Copy-Item -Path $_.FullName -Destination $path -Force; " ^
    "   Write-Host \"Copied $($_.Name) to $path\"; " ^
    "}"

echo Running Gradle build...
if exist "gradlew.bat" (
    call gradlew.bat build
) else (
    echo Gradle wrapper not found, trying 'gradle' command...
    call gradle build
)

echo Setup complete. JAR file should be in dist/
:: Optional: Clean up target? User request was vague about "target", assumig they meant build artifacts or temp files, but usually we keep dist/.
:: "apaga os arquivos desnecessarios da pasta target depois deter copiado para a files"
:: This suggests cleaning up the build directory or similar.
:: For now, we leave it as is unless specific target cleanup is needed.
pause
