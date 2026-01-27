#!/bin/bash

# Ensure files directory exists
if [ ! -d "files" ]; then
    echo "Error: 'files' directory not found."
    exit 1
fi

echo "Welcome to the Project Setup Script"
echo "-----------------------------------"

# Interactive Prompts
read -p "Enter Project Name (e.g., MyPlugin): " PROJECT_NAME
read -p "Enter Author Name: " AUTHOR_NAME
read -p "Enter Website URL: " WEBSITE_URL
read -p "Enter Package Name (e.g., com.example.myplugin): " PACKAGE_NAME
read -p "Enter Project Version (default: 1.0.0): " PROJECT_VERSION
: ${PROJECT_VERSION:=1.0.0}

if [ -z "$PROJECT_NAME" ] || [ -z "$PACKAGE_NAME" ]; then
    echo "Error: Project Name and Package Name are required."
    exit 1
fi

# 1. Update Gradle Configs
echo "Updating Gradle configurations..."
sed -i "s/rootProject.name = 'ExamplePlugin'/rootProject.name = '$PROJECT_NAME'/" settings.gradle
sed -i "s/group = 'com.cookie.test'/group = '$PACKAGE_NAME'/" build.gradle

# 2. Create Resources & Copy Manifest
echo "Creating resources..."
mkdir -p src/main/resources
if [ -f "files/manifest.json" ]; then
    # Copy manifest to resources
    cp files/manifest.json src/main/resources/
fi

# 3. Update manifest.json (THE COPY)
echo "Updating manifest.json..."
MANIFEST_PATH="src/main/resources/manifest.json"

if [ -f "$MANIFEST_PATH" ]; then
    # Update Group (top level)
    sed -i "s/\"Group\": \".*\"/\"Group\": \"$PACKAGE_NAME\"/" "$MANIFEST_PATH"

    # Update Project Name (2 spaces indent)
    sed -i "s/^  \"Name\": \".*\"/  \"Name\": \"$PROJECT_NAME\"/" "$MANIFEST_PATH"

    # Update Version (2 spaces indent)
    sed -i "s/^  \"Version\": \".*\"/  \"Version\": \"$PROJECT_VERSION\"/" "$MANIFEST_PATH"

    # Update Author Name (6 spaces indent)
    sed -i "s/^      \"Name\": \".*\"/      \"Name\": \"$AUTHOR_NAME\"/" "$MANIFEST_PATH"

    # Update URLs
    sed -i "s|\"Url\": \".*\"|\"Url\": \"$WEBSITE_URL\"|g" "$MANIFEST_PATH"
    sed -i "s|\"Website\": \".*\"|\"Website\": \"$WEBSITE_URL\"|" "$MANIFEST_PATH"

    # Update Main Class package in manifest
    # We replace the prefix of the Main class
    sed -i "s/\"Main\": \"com.cookie.test/\"Main\": \"$PACKAGE_NAME/g" "$MANIFEST_PATH"
else
    echo "Warning: manifest.json not found in src/main/resources/"
fi


# 4. Process Java Files & Refactor
echo "Refactoring and moving Java files..."

PACKAGE_PATH=$(echo "$PACKAGE_NAME" | sed 's/\./\//g')
# We don't create the base package path here blindly, we calculate it per file.

OLD_PACKAGE="com.cookie.test"

find files -name "*.java" | while read file; do
    echo "Processing $(basename "$file")..."
    
    # 1. Read file content
    # 2. Determine new package declaration and path based on OLD_PACKAGE prefix replacement
    
    # Get current package from file
    # e.g. "package com.cookie.test.commands;"
    CURRENT_PKG_LINE=$(grep "^package " "$file" | head -n 1) # package com.cookie.test.commands;
    CURRENT_PKG=$(echo "$CURRENT_PKG_LINE" | sed 's/package //; s/;//; s/ //g' | tr -d '\r') # com.cookie.test.commands
    
    # Replace OLD_PACKAGE prefix with NEW_PACKAGE
    # e.g. com.cookie.test.commands -> com.cookie.lalala.commands
    NEW_PKG=$(echo "$CURRENT_PKG" | sed "s/^$OLD_PACKAGE/$PACKAGE_NAME/")
    
    # Convert package to path
    NEW_PATH=$(echo "$NEW_PKG" | sed 's/\./\//g')
    
    FINAL_DIR="src/main/java/$NEW_PATH"
    mkdir -p "$FINAL_DIR"
    
    # Copy file to destination
    cp "$file" "$FINAL_DIR/"
    DEST_FILE="$FINAL_DIR/$(basename "$file")"
    
    # Modify the file AT THE DESTINATION
    # Replace package definition (prefix only)
    sed -i "s/^package $OLD_PACKAGE/package $PACKAGE_NAME/" "$DEST_FILE"
    
    # Replace imports (prefix only)
    sed -i "s/import $OLD_PACKAGE/import $PACKAGE_NAME/g" "$DEST_FILE"
    
done

# 5. Build
echo "Running Gradle build..."
if [ -f "./gradlew" ]; then
    chmod +x gradlew
    ./gradlew build
else
    echo "Error: Gradle wrapper './gradlew' not found."
    echo "Please ensure you are running this script from the project root."
    exit 1
fi

echo "Setup complete. JAR file should be in dist/"
