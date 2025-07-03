#!/bin/bash
# FILE: CopyEnvironmentVariables.sh
# This script copies environment variables from one GitHub environment to another.
# It uses the GitHub CLI (gh) to fetch variables from a source environment and set them in a destination environment.
# Preconditions:
# 1. The GitHub CLI (gh) must be installed and authenticated.
# 2. The user must have permissions to read and write environment variables in the specified repository.
# 3. The source environment must exist and contain variables to copy.
# 4. The destination environment must exist.
# Usage:
#   ./CopyEnvironmentVariables.sh
#   Ensure you have set the OWNER, REPO, SOURCE_ENV, and DEST_ENV variables
#   in the script before running it.    

# --- Configuration ---
# Your GitHub username or organization name
OWNER="your-org-or-username"
# Your repository name
REPO="your-repository-name"
# The environment to copy FROM
SOURCE_ENV="dev"
# The environment to copy TO
DEST_ENV="staging"

# Ensure you are logged in to the gh cli
gh auth status

echo "Fetching variables from environment: ${SOURCE_ENV}..."

# Get all variable names from the source environment
# The output is a list of variable names, one per line.
variable_names=$(gh variable list --env "${SOURCE_ENV}" --repo "${OWNER}/${REPO}" --json name -q '.[].name')

if [ -z "$variable_names" ]; then
    echo "No variables found in environment '${SOURCE_ENV}'."
    exit 0
fi

echo "Found variables: ${variable_names}"
echo "---"

# Loop through each variable name
for var_name in $variable_names; do
    echo "Processing variable: ${var_name}..."
    
    # Get the value of the variable from the source environment
    var_value=$(gh variable get "${var_name}" --env "${SOURCE_ENV}" --repo "${OWNER}/${REPO}")
    
    # Set the variable in the destination environment
    echo "Setting variable '${var_name}' in environment '${DEST_ENV}'..."
    gh variable set "${var_name}" --env "${DEST_ENV}" --repo "${OWNER}/${REPO}" --body "${var_value}"
    
    echo "Variable '${var_name}' copied successfully."
    echo "---"
done

echo "All variables have been copied from '${SOURCE_ENV}' to '${DEST_ENV}'."