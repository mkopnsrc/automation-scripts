#!/bin/sh

: <<'#HEADER_COMMENTS'
ScriptName: kill-rclone-sync-jobs.sh
Created: 2025-02-23
Updated: 2025-02-23
Version: 20250223
Author:  mkopnsrc

Description: This script checks for running rclone sync processes, displays them, and terminates them if found.
Requirements: bash shell, ps, grep, awk, xargs, and kill commands available; user must have permission to kill processes.
Functionality: Lists all running rclone sync jobs, extracts their PIDs, and kills them with SIGKILL (-9) if any exist.
Usage: Save as kill-rclone-sync-jobs.sh, make executable with `chmod +x kill-rclone-sync-jobs.sh`, 
       then run `./kill-rclone-sync-jobs.sh` manually or as part of an automation routine.
#HEADER_COMMENTS

# Step 1: Find rclone sync processes
echo "Checking for running rclone sync processes..."
RC_JOBS=$(ps auxww | grep 'rclone sync' | awk '{print $0}')

# Step 2: Check if any rclone jobs were found
if [ -n "$RC_JOBS" ]; then
    echo -e "Found the following rclone sync jobs:\n$RC_JOBS\n"

    # Extract PIDs safely
    RC_JOBS_ID=$(echo "$RC_JOBS" | awk '{print $2}' | xargs)
    if [ -z "$RC_JOBS_ID" ]; then
        echo "Error: Failed to extract PIDs from rclone jobs."
        exit 1
    fi

    # Step 3: Kill the jobs
    echo "Killing rclone jobs with PIDs: $RC_JOBS_ID"
    if ! kill -9 $RC_JOBS_ID 2>/dev/null; then
        echo "Warning: Failed to kill some or all rclone jobs. Check permissions or process status."
        exit 1
    fi
    echo "Rclone jobs terminated successfully."
else
    echo "No rclone sync jobs found."
fi

exit 0
