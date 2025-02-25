#!/bin/sh       
                                                                                                                                                  
: <<'#HEADER_COMMENTS'
ScriptName: unraid-flash-backup.sh
Created: 2025-02-23
Updated: 2025-02-25
Version: 20250225
Author: mkopnsrc

Description: This script automates the backup of an unRAID server's flash drive, moves the backup to a specified directory,
             manages backup retention by keeping a specified number of recent backups, and sends notifications based on execution status.

Requirements: unRAID OS with /usr/local/emhttp/webGui/scripts/flash_backup and notify scripts available,
              write access to the specified backup directory, bash shell, mountpoint command.
              
Functionality: Verifies if the backup directory is on a local path or mount and ensures mounts are accessible, removes excess backups beyond a specified count,
               executes flash backup, moves the resulting ZIP file to a user-defined directory, and sends notifications (normal, warning, or alert)
               for each step’s success or failure. Cleaning up old backups first ensures disk space is freed before creating a new backup,
               which could be critical if storage is limited. Notifications can be disabled or filtered by severity via configuration variables.

Usage: Save this script to a file (e.g., flash_backup.sh), make it executable with `chmod +x flash_backup.sh`,
       then run it manually or via a cron job (e.g., `0 2 * * * /path/to/flash_backup.sh` for daily at 2 AM).
#HEADER_COMMENTS

:<<'#SCRIPT_VERSION_HISTORY'
20250225
========
    - Added notification enhancements:
      - Introduced ENABLE_ALERTS (default: true) to toggle notifications.
      - Added ALERT_SEVERITIES (default: "normal warning alert") to filter notification severities.
      - Modified notify() to respect ENABLE_ALERTS and ALERT_SEVERITIES, falling back to console output.
      - Converted all echo statements to notify() with severity levels (normal, warning, alert).
      - Added warning notification ("Flash backup is in progress...") when backup starts.
      - Added normal notification ("Flash backup completed...") before symlink handling and file move.

    - Improved error handling:
      - Added failure/warning notifications for command execution errors (e.g., backup failure, file move issues).

    - Changed backup retention:
      - Replaced DAYS_TO_KEEP with BACKUPS_TO_KEEP (default: 10) to keep the last X backups.
      - Updated cleanup to sort backups by name and retain BACKUPS_TO_KEEP using find, sort, tail, xargs.

    - Enhanced BACKUP_DIR validation:
      - Removed auto-creation; fails with alert if BACKUP_DIR doesn’t exist.
      - Added mountpoint check to verify if BACKUP_DIR is local or a mount; fails if mount is inaccessible (via df).
      - Added mountpoint command dependency check.

    - Refined backup file handling:
      - Replaced generic root directory search with specific symlink check in /usr/local/emhttp/.
      - Predicted filename using bash equivalents of PHP variables ($server, $osVersion, $mydate).
      - Resolved symlink to original file with readlink -f, moved it to BACKUP_DIR, and removed symlink.
      - Added notifications for symlink location, resolution, move, and removal, with alerts for failures.

    - Miscellaneous:
      - Updated Requirements to include mountpoint.
      - Adjusted notification messages for clarity and context (e.g., mount status, backup progress).
#SCRIPT_VERSION_HISTORY

# USER CONFIGURATIONS
BACKUP_DIR="/mnt/user/backup/unraid/_flash/"
BACKUPS_TO_KEEP=10  # Number of most recent backups to retain
ENABLE_ALERTS=true  # Set to false to disable all notifications
ALERT_SEVERITIES="normal warning alert"  # Space-separated list of severities to show (options: normal, warning, alert)

# (DO NOT CHANGE) unRaid Built-in scripts and Paths
FLASH_BACKUP_SCRIPT="/usr/local/emhttp/webGui/scripts/flash_backup"
NOTIFY_SCRIPT="/usr/local/emhttp/webGui/scripts/notify"
TEMP_DIR="/usr/local/emhttp/"

# Notification function
notify() {
    local severity="$1"
    local message="$2"
    local subject="Flash Backup Status"
    local event="FlashBackup"

    # If alerts are disabled, output to console only
    if [ "$ENABLE_ALERTS" = false ]; then
        echo "$message"
        return
    fi

    # Check if the severity is in the ALERT_SEVERITIES list
    if ! echo "$ALERT_SEVERITIES" | grep -qw "$severity"; then
        echo "$message"  # Output to console if severity is filtered out
        return
    fi

    if [ -x "$NOTIFY_SCRIPT" ]; then
        "$NOTIFY_SCRIPT" -e "$event" -s "$subject" -d "$message" -i "$severity"
    else
        echo "Warning: Notification script not found or not executable. Message: $message"
    fi
}

# Check if mountpoint command is available
if ! command -v mountpoint >/dev/null 2>&1; then
    notify "alert" "Required 'mountpoint' command not found. Please install it (e.g., via unRAID Nerd Tools)."
    exit 1
fi

# Check if BACKUP_DIR exists and determine if it's a mount or local path
if [ ! -d "$BACKUP_DIR" ]; then
    notify "alert" "Backup directory '$BACKUP_DIR' does not exist and will not be created automatically."
    exit 1
else
    if mountpoint -q "$BACKUP_DIR"; then
        notify "normal" "Backup directory '$BACKUP_DIR' is a mount point. Verifying accessibility..."
        if ! df "$BACKUP_DIR" >/dev/null 2>&1; then
            notify "alert" "Backup directory '$BACKUP_DIR' is a mount but not accessible (possibly unmounted or stale). Script cannot proceed."
            exit 1
        fi
        notify "normal" "Mount point '$BACKUP_DIR' is accessible."
    else
        notify "normal" "Backup directory '$BACKUP_DIR' is a local path."
    fi
fi

# Check if backup directory is writable
if [ ! -w "$BACKUP_DIR" ]; then
    notify "alert" "Backup directory '$BACKUP_DIR' is not writable. Check permissions."
    exit 1
fi

# Step 1: Delete old backups (keep last X backups)
notify "normal" "Cleaning up backups, keeping the last $BACKUPS_TO_KEEP..."
TOTAL_BACKUPS=$(find "$BACKUP_DIR" -type f -name '*-flash-backup-*.zip' | wc -l)
if [ "$TOTAL_BACKUPS" -gt "$BACKUPS_TO_KEEP" ]; then
    find "$BACKUP_DIR" -type f -name '*-flash-backup-*.zip' -print0 | 
        sort -z -r | 
        tail -z -n +$((BACKUPS_TO_KEEP + 1)) | 
        xargs -0 rm -fv &&
        notify "normal" "Successfully removed excess backups." || 
        notify "warning" "Failed to delete some old backups. Check permissions or files."
else
    notify "normal" "No excess backups to remove. Total found: $TOTAL_BACKUPS."
fi

# Step 2: Execute native unRAID flash backup script
notify "warning" "Flash backup is in progress..."
if [ ! -x "$FLASH_BACKUP_SCRIPT" ]; then
    notify "alert" "Flash backup script '$FLASH_BACKUP_SCRIPT' not found or not executable."
    exit 1
fi

if ! "$FLASH_BACKUP_SCRIPT"; then
    notify "alert" "Flash backup script failed to execute."
    exit 1
fi

# Step 3: Locate and handle the symlink
notify "normal" "Flash backup completed. Locating symlink in '$TEMP_DIR'..."

# Translate PHP variables to bash
SERVER_NAME=$(hostname | tr '[:upper:]' '[:lower:]' | tr ' ' '_')  # Default to 'tower' if not set
[ -z "$SERVER_NAME" ] && SERVER_NAME="tower"
MYDATE=$(date '+%Y%m%d-%H%M')  # Format: YYYYMMDD-HHMM
OS_VERSION=$(cat /etc/unraid-version 2>/dev/null | grep -oP '(?<=version=")[^"]+' || echo "_unknown")
BACKUP_FILENAME="${SERVER_NAME}-v${OS_VERSION}-flash-backup-${MYDATE}.zip"
SYMLINK_PATH="${TEMP_DIR}/${BACKUP_FILENAME}"

# Check if symlink exists
if [ -L "$SYMLINK_PATH" ]; then
    notify "normal" "Symlink found: '$SYMLINK_PATH'."
    ORIGINAL_FILE=$(readlink -f "$SYMLINK_PATH")
    if [ -z "$ORIGINAL_FILE" ] || [ ! -f "$ORIGINAL_FILE" ]; then
        notify "alert" "Symlink '$SYMLINK_PATH' exists but points to an invalid or missing file."
        exit 1
    fi
else
    notify "alert" "Expected symlink '$SYMLINK_PATH' not found in '$TEMP_DIR' after backup."
    exit 1
fi

# Step 4: Move the original file and remove the symlink
notify "normal" "Flash backup completed. Moving backup file from '$ORIGINAL_FILE' to '$BACKUP_DIR'..."
if ! mv "$ORIGINAL_FILE" "$BACKUP_DIR"; then
    notify "alert" "Failed to move backup file to '$BACKUP_DIR'. Check permissions or disk space."
    exit 1
fi

notify "normal" "Removing symlink '$SYMLINK_PATH'..."
if ! rm -f "$SYMLINK_PATH"; then
    notify "warning" "Failed to remove symlink '$SYMLINK_PATH'. Proceeding anyway..."
fi

# Step 5: Notify completion
notify "normal" "Flash backup completed successfully."
notify "normal" "All done!"

exit 0
