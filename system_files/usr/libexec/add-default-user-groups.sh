#!/bin/bash
set -euo pipefail

MARKER="/var/lib/.user-groups-initialized"
[[ -f "$MARKER" ]] && exit 0

users=$(awk -F: '$3>=1000 && $3<65534 {print $1}' /etc/passwd | paste -sd, -)
[[ -z "$users" ]] && exit 0

# Append local override entries to /etc/group for the standard device groups.
# The base groups live in /usr/lib/group; /etc/group entries override them.
echo "audio:x:63:${users}" >> /etc/group
echo "video:x:39:${users}" >> /etc/group
echo "kvm:x:36:${users}" >> /etc/group
echo "render:x:105:${users}" >> /etc/group
echo "input:x:104:${users}" >> /etc/group

touch "$MARKER"
