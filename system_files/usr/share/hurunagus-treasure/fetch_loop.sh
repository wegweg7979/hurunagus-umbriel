#!/bin/bash
# Clear terminal and run for the first time
clear
fastfetch

while true; do
    # Wait for 60 minutes (3600 seconds)
    sleep 3600

    # Clear the screen to keep it tidy
    clear
    fastfetch

    # Optional: Log the last run time
    #echo "Last updated: $(date +%H:%M:%S)"
done
