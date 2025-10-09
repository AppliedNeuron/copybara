#!/usr/bin/env bash

set -eo pipefail

# =============================================================================
# LFS WORKAROUND SCRIPT OVERVIEW
# =============================================================================
#
# Copybara does not currently handle Git LFS files seamlessly. When LFS files
# are present, the process can fail because GIT_LFS_SKIP_SMUDGE is set to 1,
# allowing Copybara to process LFS references from the source repo but not
# actually download the LFS file contents. This results in push failures.
#
# OVERALL APPROACH:
# We implement a workaround that restores the remote URL and pulls the LFS
# files into the worktree, then retries the copybara operation. The process
# follows a do-while pattern:
#
# 1. Try copybara command
# 2. If LFS error detected:
#    a. Extract git_dest directory from error message
#    b. Set up git directories (destination and source)
#    c. Track commit hash for infinite loop prevention
#    d. Perform LFS workaround (detailed commands below)
#    e. Retry copybara command
# 3. If copybara succeeds or non-LFS error detected, exit
# 4. Repeat until success or max retries reached
#
# LFS WORKAROUND DETAILED COMMANDS:
# Step 1: Add remote URL to destination repo
#   git --git-dir=<dest git dir> --work-tree=<dest worktree dir> config remote.origin.url git@github.com:AppliedNeuron/core-stack.git
#
# Step 2: Pull LFS files into worktree
#   git --git-dir=<dest git dir> --work-tree=<dest worktree dir> lfs pull
#
# Step 3: Remove remote URL from destination repo
#   git --git-dir=<dest git dir> --work-tree=<dest worktree dir> config --unset remote.origin.url
#
# =============================================================================

# Parse command line arguments
if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <SRC_REF> <GITHUB_CREDS_FILE> <DESTINATION>"
    echo "Example: $0 master /tmp/github_creds brain2-poc"
    echo "DESTINATION must be either 'brain2' or 'brain2-poc'"
    exit 1
fi

SRC_REF=$1
GITHUB_CREDS_FILE=$2
DESTINATION=$3

# Validate destination parameter
if [[ "$DESTINATION" != "brain2" && "$DESTINATION" != "brain2-poc" ]]; then
    echo "Error: DESTINATION must be either 'brain2' or 'brain2-poc', got: $DESTINATION"
    exit 1
fi

# Global variable to store extracted git_dest directory from LFS errors
EXTRACTED_GIT_DEST_WORK_TREE_DIR=""

echo "Starting mirror process with SRC_REF: $SRC_REF"
echo "Using credentials file: $GITHUB_CREDS_FILE"
echo "Using destination: $DESTINATION"

# Define success patterns that should cause immediate exit
SUCCESS_PATTERNS=(
    "No new changes to import for resolved ref"
)

# Function to detect and extract LFS error pattern from copybara output
detect_lfs_error() {
    local output_file=$1
    local context=$2

    echo "Checking for success patterns and LFS errors ($context)..."

    # First check for success patterns
    for pattern in "${SUCCESS_PATTERNS[@]}"; do
        if grep -q "$pattern" "$output_file"; then
            echo "SUCCESS: Detected success pattern ($context): '$pattern'"
            rm -f "$output_file"
            exit 0
        fi
    done

    # Look for LFS error pattern
    # Pattern: ERROR: Error executing 'git --git-dir=<home>/copybara/cache/git_repos/git%40github%2Ecom%3AExt-Applied-Frontier%2Fbrain2-poc%2Egit --work-tree=<home>/copybara/temp/git_dest<random> push --progress git@github.com:Ext-Applied-Frontier/brain2-poc.git HEAD:refs/heads/master'(exit code 1). Stderr: error: failed to push some refs to 'github.com:Ext-Applied-Frontier/brain2-poc.git'
    local lfs_error_pattern="Error executing.*git_dest[0-9]*.*failed to push some refs"

    if grep -E "$lfs_error_pattern" "$output_file" > /dev/null; then
        echo "LFS ERROR: Detected LFS-related failure ($context)"

        # Reset the extracted directory variable to ensure no leftover values
        EXTRACTED_GIT_DEST_WORK_TREE_DIR=""

        # Extract the git_dest directory from the error message
        local git_dest_match
        git_dest_match=$(grep -E "$lfs_error_pattern" "$output_file" | sed -E 's/.*--work-tree=([^[:space:]]*git_dest[0-9]*).*/\1/;q')

        if [[ -n "$git_dest_match" ]]; then
            echo "Extracted git_dest directory: $git_dest_match"

            # Extract the home directory from the git_dest path
            local extracted_home_dir
            extracted_home_dir=$(echo "$git_dest_match" | sed 's|/copybara/temp/git_dest[0-9]*||')

            # Verify the extracted home directory matches $HOME
            if [[ "$extracted_home_dir" != "$HOME" ]]; then
                echo "ERROR: Extracted home directory '$extracted_home_dir' does not match current \$HOME '$HOME'"
                rm -f "$output_file"
                exit 1
            fi

            echo "Verified home directory matches: $HOME"
            # Set the extracted directory for use in the main script
            EXTRACTED_GIT_DEST_WORK_TREE_DIR="$git_dest_match"
        fi

        echo "This appears to be an LFS-related error that can be resolved with the LFS workaround."
    else
        echo "ERROR: Could not extract git_dest directory from error message"
        rm -f "$output_file"
        exit 1
    fi
}

# Function to run copybara with error checking
# This function will EXIT the script if:
# - Copybara succeeds (exit 0)
# - Non-LFS error is detected (exit 1)
# It will NOT exit if LFS error is detected (allows workaround to continue)
run_copybara_with_error_check() {
    local copybara_cmd=$1
    local context=$2
    local output_file
    output_file=$(mktemp)

    echo "Running copybara command ($context):"
    echo "$copybara_cmd"

    # Use tee to show live output AND capture it for error analysis
    # Use script to create pseudo-TTY and preserve colors
    if script -qec "$copybara_cmd" /dev/null 2>&1 | tee "$output_file"; then
        echo "Copybara succeeded ($context)"
        rm -f "$output_file"
        exit 0
    else
        echo "Copybara failed ($context), analyzing error..."
        detect_lfs_error "$output_file" "$context"
        # If we reach here, LFS error was detected and we should continue with workaround
        rm -f "$output_file"
    fi
}

# Function to perform LFS workaround steps
perform_lfs_workaround() {
    local attempt_number=$1
    local dest_git_dir=$2

    echo "Performing LFS workaround (attempt $attempt_number)..."

    # Verify we have the extracted destination worktree directory
    if [[ -z "$EXTRACTED_GIT_DEST_WORK_TREE_DIR" ]]; then
        echo "Error: No extracted destination worktree directory provided (EXTRACTED_GIT_DEST_WORK_TREE_DIR is empty)"
        exit 1
    fi
    echo "Using destination worktree directory: $EXTRACTED_GIT_DEST_WORK_TREE_DIR"

    # LFS Workaround Step 1: Add the remote.origin.url to the destination repo
    echo "Adding remote.origin.url to the destination repo..."
    if git --git-dir="$dest_git_dir" --work-tree="$EXTRACTED_GIT_DEST_WORK_TREE_DIR" config remote.origin.url git@github.com:AppliedNeuron/core-stack.git; then
        echo "Remote.origin.url added successfully"
    else
        echo "Warning: Remote.origin.url addition failed, exiting"
        exit 1
    fi

    # LFS Workaround Step 2: Force pull the git lfs files to the worktree
    echo "Pulling LFS files..."
    if git --git-dir="$dest_git_dir" --work-tree="$EXTRACTED_GIT_DEST_WORK_TREE_DIR" lfs pull; then
        echo "LFS pull succeeded"
    else
        echo "Warning: LFS pull failed, but continuing with copybara retry"
    fi

    # LFS Workaround Step 3: Unset the remote.origin.url in the destination repo
    echo "Unsetting remote.origin.url in the destination repo..."
    if git --git-dir="$dest_git_dir" --work-tree="$EXTRACTED_GIT_DEST_WORK_TREE_DIR" config --unset remote.origin.url; then
        echo "Remote.origin.url unset successfully"
    else
        echo "Warning: Remote.origin.url unset failed, exiting"
        exit 1
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

# Initialize copybara command and retry variables
# Select the appropriate workflow based on destination
if [[ "$DESTINATION" == "brain2" ]]; then
    WORKFLOW_NAME="mirror_to_brain2"
else
    WORKFLOW_NAME="mirror_to_brain2-poc"
fi

COPYBARA_CMD="copybara /stack/release/customer/brain2/copybara/copy.bara.sky $WORKFLOW_NAME $SRC_REF --force --init-history --git-credential-helper-store-file $GITHUB_CREDS_FILE"

MAX_RETRIES=100
RETRY_COUNT=0
PREVIOUS_COMMIT_HASH=""

# Do-while pattern: Try copybara, if LFS error detected, perform workaround and retry
while true; do
    # Step 1: Try copybara command
    # This will exit if copybara succeeds or if non-LFS error is detected
    # If we reach the next line, it means LFS error was detected
    run_copybara_with_error_check "$COPYBARA_CMD" "attempt $((RETRY_COUNT + 1))"

    echo "LFS error detected, implementing LFS workaround..."

    # Step 2.b: Set up directories (temp, cache, destination git, source git)
    COPYBARA_TEMP_DIR="$HOME/copybara/temp"
    COPYBARA_CACHE_DIR="$HOME/copybara/cache/git_repos"
    echo "COPYBARA_TEMP_DIR: $COPYBARA_TEMP_DIR"
    echo "COPYBARA_CACHE_DIR: $COPYBARA_CACHE_DIR"

    # Find the destination git directory
    DEST_GIT_DIR="$COPYBARA_CACHE_DIR/git%40github%2Ecom%3AExt-Applied-Frontier%2F$DESTINATION%2Egit"
    if [[ ! -d "$DEST_GIT_DIR" ]]; then
        echo "Error: Could not find git directory: $DEST_GIT_DIR"
        exit 1
    fi
    echo "Found git directory: $DEST_GIT_DIR"

    # Find the source git directory
    SRC_GIT_DIR="$COPYBARA_CACHE_DIR/git%40github%2Ecom%3AAppliedNeuron%2Fcore-stack%2Egit"
    if [[ ! -d "$SRC_GIT_DIR" ]]; then
        echo "Error: Could not find git directory: $SRC_GIT_DIR"
        exit 1
    fi
    echo "Found git directory: $SRC_GIT_DIR"

    # Step 2.c: Track git commit hash for infinite loop prevention
    CURRENT_COMMIT_HASH=$(git --git-dir="$SRC_GIT_DIR" log --pretty=format:%H -n 1 2>/dev/null || echo "")

    if [[ -z "$CURRENT_COMMIT_HASH" ]]; then
        echo "Warning: Could not get commit hash, exiting"
        exit 1
    fi

    echo "Current commit hash: $CURRENT_COMMIT_HASH"

    # Check if we're stuck on the same commit (infinite loop prevention)
    if [[ "$CURRENT_COMMIT_HASH" == "$PREVIOUS_COMMIT_HASH" ]]; then
        echo "Error: Same commit hash as previous attempt, there are other issues preventing copybara from succeeding"
        exit 1
    fi
    PREVIOUS_COMMIT_HASH=$CURRENT_COMMIT_HASH

    # Check retry limit
    if [[ $RETRY_COUNT -ge $MAX_RETRIES ]]; then
        echo "Error: Copybara failed after $MAX_RETRIES retries with LFS workaround"
        exit 1
    fi

    # Step 2.d: Perform LFS workaround
    perform_lfs_workaround $((RETRY_COUNT + 1)) "$DEST_GIT_DIR"

    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Completed LFS workaround attempt $RETRY_COUNT, retrying copybara..."
done
