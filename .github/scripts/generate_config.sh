#!/bin/bash

ISSUE_TEMPLATE_CREATED_FILE=".github/ISSUE_TEMPLATE/issue_template_configured.txt"
TEMPLATE_FILE=".github/ISSUE_TEMPLATE/config.template.yml"
OUTPUT_FILE=".github/ISSUE_TEMPLATE/config.yml"

# Check if the repository name is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <repository-name>"
  exit 1
fi

# Capture the repository name
REPO="$1"

# Check if the config has already been generated
if [ -f "$ISSUE_TEMPLATE_CREATED_FILE" ]; then
  echo "Config has already been generated."
  exit 0
fi

# Ensure the output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Replace placeholder {REPO} with the actual repository name
sed "s|{REPO}|$REPO|g" "$TEMPLATE_FILE" > "$OUTPUT_FILE"

# Create a file to indicate the script has run, with a timestamp
echo "Config generated for repository: $REPO on $(date '+%Y-%m-%d %H:%M:%S')" > "$ISSUE_TEMPLATE_CREATED_FILE"

echo "Generated config.yml for repository: $REPO"
