#!/bin/bash

LOG_FILE="/path/to/log/file.log"

# Function to log messages
log_message() {
  echo "$(date): $1" >> "$LOG_FILE" 2>> "$LOG_FILE"
}

# Try to create the log file or append to it, then check if successful
touch "$LOG_FILE" 2>> /dev/null
if [ ! -w "$LOG_FILE" ]; then
  echo "Cannot write to log file $LOG_FILE. Exiting."
  exit 1
fi

# Check if running as root, exit if not
if [ "$EUID" -ne 0 ]; then
  log_message "Script must be run as root. Exiting."
  exit 1
fi

# Safety check and clear system cache
if [ -d "/System/Library/Caches/" ]; then
  sudo rm -rf /System/Library/Caches/* || log_message "Failed to clear System Cache."
else
  log_message "System cache directory does not exist. Skipping."
fi

# Safety check and clear user cache
if [ -d "~/Library/Caches/" ]; then
  rm -rf ~/Library/Caches/* || log_message "Failed to clear User Cache."
else
  log_message "User cache directory does not exist. Skipping."
fi

# Safety check and clear Safari cache
if [ -f "~/Library/Safari/Cache.db" ]; then
  rm -rf ~/Library/Safari/Cache.db || log_message "Failed to clear Safari Cache."
else
  log_message "Safari cache does not exist. Skipping."
fi

# Safety check and clear Chrome cache
if [ -d "~/Library/Caches/Google/Chrome/" ]; then
  rm -rf ~/Library/Caches/Google/Chrome/* || log_message "Failed to clear Chrome Cache."
else
  log_message "Chrome cache directory does not exist. Skipping."
fi

# Clear DNS Cache
sudo dscacheutil -flushcache || log_message "Failed to flush DNS Cache."
sudo killall -HUP mDNSResponder || log_message "Failed to restart mDNSResponder."

log_message "Cache clearing process completed."
