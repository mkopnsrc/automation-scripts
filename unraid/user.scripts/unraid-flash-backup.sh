#!/bin/sh                                                                                                                                                         
: <<'#HEADER_COMMENTS'
ScriptName: unraid-flash-backup.sh
Created: 2025-02-23
Updated: 2025-02-23
Version: 20250223
Author: mkopnsrc

Description: This script automates the backup of an unRAID server's flash drive, moves the backup to a specified directory,
             deletes older backups, and optionally sends a notification upon completion.
Requirements: unRAID OS with /usr/local/emhttp/webGui/scripts/flash_backup and notify scripts available,
              write access to the specified backup directory, bash shell.
Functionality: Removes backups older than a specified number of days, executes flash backup, 
               moves the resulting ZIP file to a user-defined directory, and sends a GUI notification if enabled.
               Cleaning up old backups first ensures disk space is freed before creating a new backup, 
               which could be critical if storage is limited.
Usage: Save this script to a file (e.g., flash_backup.sh), make it executable with `chmod +x flash_backup.sh`,
       then run it manually or via a cron job (e.g., `0 2 * * * /path/to/flash_backup.sh` for daily at 2 AM).
#HEADER_COMMENTS

# Configuration
BACKUP_DIR="/mnt/user/backup/unraid/_flash/"
DAYS_TO_KEEP=15
FLASH_BACKUP_SCRIPT="/usr/local/emhttp/webGui/scripts/flash_backup"
TEMP_DIR="/usr/local/emhttp/"
NOTIFY_SCRIPT="/usr/local/emhttp/webGui/scripts/notify"

# Ensure backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Error: Backup directory '$BACKUP_DIR' does not exist."
    echo "Creating directory '$BACKUP_DIR'..."
    if ! mkdir -p "$BACKUP_DIR"; then
        echo "Error: Failed to create backup directory. Check permissions or path."
        exit 1
    fi
fi

# Check if backup directory is writable
if [ ! -w "$BACKUP_DIR" ]; then
    echo "Error: Backup directory '$BACKUP_DIR' is not writable. Check permissions."
    exit 1
fi

# Step 1: Delete old backups (moved to top)
echo "Deleting backups older than $DAYS_TO_KEEP days..."
find "$BACKUP_DIR" -type f -name '*-flash-backup-*.zip' -mtime "+$DAYS_TO_KEEP" -exec rm -fv {} \;
if [ $? -ne 0 ]; then
    echo "Warning: Failed to delete some old backups. Check permissions or files."
fi

# Step 2: Execute native unRAID flash backup script
echo "Executing native unRAID backup script..."
if [ ! -x "$FLASH_BACKUP_SCRIPT" ]; then
    echo "Error: Flash backup script '$FLASH_BACKUP_SCRIPT' not found or not executable."
    exit 1
fi

if ! "$FLASH_BACKUP_SCRIPT"; then
    echo "Error: Flash backup script failed to execute."
    exit 1
fi

# Step 3: Remove symlink or temp file from emhttp directory
echo "Removing temporary flash backup files from '$TEMP_DIR'..."
find "$TEMP_DIR" -maxdepth 1 -name '*-flash-backup-*.zip' -delete
if [ $? -ne 0 ]; then
    echo "Warning: Failed to remove temporary files. Proceeding anyway..."
fi

# Brief pause to ensure file operations complete
sleep 2

# Step 4: Move flash backup ZIP to destination
echo "Moving flash backup ZIP to '$BACKUP_DIR'..."
BACKUP_FILE=$(find / -maxdepth 1 -name '*-flash-backup-*.zip' 2>/dev/null)
if [ -z "$BACKUP_FILE" ]; then
    echo "Error: No flash backup ZIP file found in root directory."
    exit 1
fi

if ! mv "$BACKUP_FILE" "$BACKUP_DIR"; then
    echo "Error: Failed to move backup file to '$BACKUP_DIR'. Check permissions or disk space."
    exit 1
fi

# Brief pause to ensure file movement completes
sleep 2

# Step 5: Notify completion
echo "Flash backup completed successfully."
if [ -x "$NOTIFY_SCRIPT" ]; then
    "$NOTIFY_SCRIPT" -e "Unraid Server Notice" -s "Flash Zip Backup" \
        -d "A copy of the Unraid flash disk has been backed up" -i "normal"
else
    echo "Warning: Notification script not found or not executable. Skipping notification."
fi

echo "All done!"
exit 0
