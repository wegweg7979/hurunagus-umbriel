#!/bin/bash
set -euo pipefail

LIST="/usr/share/ublue-os/flatpaks/system-flatpaks.list"

if [[ ! -f "$LIST" ]]; then
    exit 0
fi

# Ensure the flathub remote exists (idempotent, in case the base service hasn't run)
flatpak remote-add --system --if-not-exists flathub /etc/flatpak/remotes.d/flathub.flatpakrepo

installed=$(flatpak list --system --app --columns=application)

while IFS= read -r app; do
    [[ -z "$app" || "$app" == \#* ]] && continue
    if ! grep -qxF "$app" <<< "$installed"; then
        echo "Installing missing flatpak: $app"
        flatpak install --system -y flathub "$app"
        installed=$(flatpak list --system --app --columns=application)
    fi
done < "$LIST"
