#!/bin/sh       
                                                                                                                                                  
: <<'#HEADER_COMMENTS'
ScriptName: unraid-flash-backup.sh
Created: 2025-02-23
Updated: 2025-02-25
Version: 20250225.4
Author: mkopnsrc

Description: This script automates the backup of an unRAID server's flash drive, moves the backup to a specified directory,
             manages backup retention by keeping a specified number of recent backups, and sends notifications based on execution status.

Requirements: unRAID OS with /usr/local/emhttp/webGui/scripts/flash_backup and notify scripts available,
              write access to the specified backup directory, bash shell, mountpoint command.

Functionality: Verifies if the backup directory is on a local path or mount and ensures mounts are accessible, removes excess backups beyond a specified count,
               executes flash backup with progress notifications, locates and moves the resulting ZIP file (via symlink resolution) to a user-defined directory,
               and sends notifications (normal, warning, or alert) for each step’s success or failure. Cleaning up old backups first ensures
               disk space is freed before creating a new backup, which could be critical if storage is limited. Notifications can be disabled or filtered by severity.

Usage: Save this script to a file (e.g., flash_backup.sh), make it executable with `chmod +x flash_backup.sh`,
       then run it manually or via a cron job (e.g., `0 2 * * * /path/to/flash_backup.sh` for daily at 2 AM).
#HEADER_COMMENTS

:<<'#SCRIPT_VERSION_HISTORY'
20250225.4
==========
    - Minor changes
      - Added space in unraid alert event name
      - Added '-e' to console debug echo
      - Removed notifications for accessible backup_dir

20250225.3
==========
    - Shortened notifications:
      - Reduced all notification messages to be short (<20 chars where possible) and meaningful.
      - Removed file paths from notifications to fit unRAID's limited notification window (e.g., "Backup in progress...", "Removed old backups.").

    - Added console debug logging:
      - Introduced ENABLE_DEBUG config option (default: true) to toggle detailed console output.
      - Modified notify() to accept a debug_msg parameter for verbose logging.
      - Added timestamped console logs with severity and full details (e.g., paths) when ENABLE_DEBUG is true.

    - Updated notification calls:
      - Each notify() call now provides a short message for unRAID and a detailed debug message for console.

    - Miscellaneous:
      - Simplified notify() logic by moving non-executable script warning to console debug output.
      - No functional changes to backup logic, only notification and logging enhancements.
      
20250225.2
==========
    - Fixed symlink timing issue:
      - Replaced static $MYDATE-based filename prediction with dynamic find command using pattern '${SERVER_NAME}-v${OS_VERSION}-flash-backup-*.zip'.
      - Added 5-second retry loop with 1-second delays to locate symlink in $TEMP_DIR, ensuring it’s found even if backup completion spans a minute boundary.
      - Updated notifications to reflect dynamic symlink detection process.

    - Fixed missing cleanup notification:
      - Rewrote Step 1 (backup cleanup) to use mapfile to capture files to remove into an array, replacing pipeline with explicit rm execution.
      - Added explicit success/failure checks for rm operation, ensuring notifications fire reliably.
      - Updated cleanup notification to report number of removed files (e.g., "Successfully removed 2 excess backups") or warn on failure.

    - Enhanced user feedback:
      - Retained warning notification ("Flash backup is in progress...") at backup start.
      - Kept normal notification ("Flash backup completed...") before symlink handling and file move.
      - Added retry attempt notifications for symlink search (e.g., "Waiting 1 second (attempt 1/5)...").

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
ENABLE_DEBUG=true  # Set to true to enable detailed console logging


# (DO NOT CHANGE) unRaid Built-in scripts and Paths
FLASH_BACKUP_SCRIPT="/usr/local/emhttp/webGui/scripts/flash_backup"
NOTIFY_SCRIPT="/usr/local/emhttp/webGui/scripts/notify"
TEMP_DIR="/usr/local/emhttp/"

# Notification function
notify() {
    local severity="$1"
    local short_msg="$2"
    local debug_msg="$3"
    local subject="Flash Backup Status"
    local event="Flash Backup"

    # Log detailed message to console if debug is enabled
    [ "$ENABLE_DEBUG" = true ] && echo -e "$(date '+%Y-%m-%d %H:%M:%S') [$severity] $debug_msg"

    # If alerts are disabled, skip notification
    if [ "$ENABLE_ALERTS" = false ]; then
        return
    fi

    # Check if the severity is in the ALERT_SEVERITIES list
    if ! echo "$ALERT_SEVERITIES" | grep -qw "$severity"; then
        return
    fi

    if [ -x "$NOTIFY_SCRIPT" ]; then
        "$NOTIFY_SCRIPT" -e "$event" -s "$subject" -d "$short_msg" -i "$severity"
        sleep 1s
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') [warning] Notification script not executable: $debug_msg"
    fi
}

# Check if mountpoint command is available
if ! command -v mountpoint >/dev/null 2>&1; then
    notify "alert" "Missing mountpoint command." "Required 'mountpoint' command not found. Please install it."
    exit 1
fi

# Check if BACKUP_DIR exists and determine if it's a mount or local path
if [ ! -d "$BACKUP_DIR" ]; then
    notify "alert" "Backup directory missing." "Backup directory '$BACKUP_DIR' does not exist and will not be created."
    exit 1
else
    if mountpoint -q "$BACKUP_DIR"; then
        notify "normal" "Checking mount..." "Checking accessibility of mount point '$BACKUP_DIR'..."
        if ! df "$BACKUP_DIR" >/dev/null 2>&1; then
            notify "alert" "Mount not accessible." "Mount '$BACKUP_DIR' is not accessible (possibly unmounted or stale)."
            exit 1
        fi
    fi
fi

# Check if backup directory is writable
if [ ! -w "$BACKUP_DIR" ]; then
    notify "alert" "Directory not writable." "Backup directory '$BACKUP_DIR' is not writable. Check permissions."
    exit 1
fi

# Step 1: Delete old backups (keep last X backups)
notify "normal" "Cleaning up backups..." "Cleaning up backups in '$BACKUP_DIR', keeping the last $BACKUPS_TO_KEEP..."
TOTAL_BACKUPS=$(find "$BACKUP_DIR" -type f -name '*-flash-backup-*.zip' | wc -l)
if [ "$TOTAL_BACKUPS" -gt "$BACKUPS_TO_KEEP" ]; then
    mapfile -t FILES_TO_REMOVE < <(find "$BACKUP_DIR" -type f -name '*-flash-backup-*.zip' -print0 | sort -z -r | tail -z -n +$((BACKUPS_TO_KEEP + 1)) | tr '\0' '\n')
    if [ ${#FILES_TO_REMOVE[@]} -gt 0 ]; then
        if rm -fv "${FILES_TO_REMOVE[@]}" >/dev/null 2>&1; then
            notify "normal" "Removed old backups." "Successfully removed ${#FILES_TO_REMOVE[@]} excess backups from '$BACKUP_DIR'."
        else
            notify "warning" "Cleanup failed." "Failed to delete some old backups in '$BACKUP_DIR'. Check permissions."
        fi
    else
        notify "warning" "No cleanup needed." "No excess backups identified in '$BACKUP_DIR', despite total exceeding limit."
    fi
else
    notify "normal" "No cleanup needed." "No excess backups to remove in '$BACKUP_DIR'. Total found: $TOTAL_BACKUPS."
fi

# Step 2: Execute native unRAID flash backup script
notify "warning" "Backup in progress..." "Executing flash backup script '$FLASH_BACKUP_SCRIPT'..."
if [ ! -x "$FLASH_BACKUP_SCRIPT" ]; then
    notify "alert" "Script not found." "Flash backup script '$FLASH_BACKUP_SCRIPT' not found or not executable."
    exit 1
fi

if ! "$FLASH_BACKUP_SCRIPT"; then
    notify "alert" "Backup failed." "Flash backup script '$FLASH_BACKUP_SCRIPT' failed to execute."
    exit 1
fi

# Step 3: Locate and handle the symlink
notify "normal" "Locating backup symlink..." "Flash backup completed. Locating symlink in '$TEMP_DIR'..."

# Get server name and OS version for pattern matching
SERVER_NAME=$(hostname | tr '[:upper:]' '[:lower:]' | tr ' ' '_')  # Default to 'tower' if not set
[ -z "$SERVER_NAME" ] && SERVER_NAME="tower"
OS_VERSION=$(cat /etc/unraid-version 2>/dev/null | grep -oP '(?<=version=")[^"]+' || echo "_unknown")

# Look for the most recent symlink matching the pattern
SYMLINK_PATH=""
for i in {1..5}; do  # Retry up to 5 times with 1-second delay
    SYMLINK_PATH=$(find "$TEMP_DIR" -maxdepth 1 -type l -name "${SERVER_NAME}-v${OS_VERSION}-flash-backup-*.zip" -print -quit)
    if [ -n "$SYMLINK_PATH" ]; then
        break
    fi
    notify "normal" "Retrying symlink..." "Symlink not found in '$TEMP_DIR'. Waiting 1 second (attempt $i/5)..."
    sleep 1
done

# Check if symlink was found
if [ -n "$SYMLINK_PATH" ]; then
    notify "normal" "Symlink found." "Symlink located: '$SYMLINK_PATH'."
    ORIGINAL_FILE=$(readlink -f "$SYMLINK_PATH")
    if [ -z "$ORIGINAL_FILE" ] || [ ! -f "$ORIGINAL_FILE" ]; then
        notify "alert" "Symlink invalid." "Symlink '$SYMLINK_PATH' points to an invalid or missing file."
        exit 1
    fi
else
    notify "alert" "Flash Backup symlink missing." "No symlink matching '${SERVER_NAME}-v${OS_VERSION}-flash-backup-*.zip' found in '$TEMP_DIR'."
    exit 1
fi

# Step 4: Move the original file and remove the symlink
notify "normal" "Moving backup..." "Moving backup file to '$BACKUP_DIR'..."
if ! mv "$ORIGINAL_FILE" "$BACKUP_DIR"; then
    notify "alert" "Move failed." "Failed to move backup file to '$BACKUP_DIR'. Check permissions or disk space."
    exit 1
fi

notify "normal" "Removing symlink..." "Removing symlink '$SYMLINK_PATH'..."
if ! rm -f "$SYMLINK_PATH"; then
    notify "warning" "Symlink not removed." "Failed to remove symlink '$SYMLINK_PATH'."
fi

# Step 5: Notify completion
notify "normal" "Flash Backup complete." "Flash backup completed successfully."
notify "normal" "All done!" "Backup process finished."

exit 0
