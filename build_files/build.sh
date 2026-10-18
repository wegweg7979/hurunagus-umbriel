#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y btop fastfetch niri foot greetd khal adwaita-fonts-all igt-gpu-tools nautilus firefox lm_sensors cups-pk-helper fprintd kf6-kimageformats noctalia tuned-ppd xorg-x11-server-Xwayland

# Terra repo provides the greetd greeter. Enable, install, then disable so it
# doesn't end up enabled on the final image (packages will be pinned to
# build-time versions).
dnf5 -y install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release terra-gpg-keys
dnf5 -y install noctalia-greeter
sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/terra*.repo

# Point greetd at the Noctalia greeter session. The greeter package configures
# greetd on some distributions but not others; only write the config if the
# session wrapper is not already referenced.
if ! grep -qs 'noctalia-greeter-session' /etc/greetd/config.toml; then
    mkdir -p /etc/greetd
    cat > /etc/greetd/config.toml <<'EOF'
[terminal]
vt = 1

[default_session]
command = "/usr/bin/noctalia-greeter-session"
user = "greeter"
EOF
fi

# Initialize greeter state (tmpfiles rule + appearance setup) per upstream docs
systemd-tmpfiles --create noctalia-greeter.conf || true
noctalia-greeter-apply-appearance --setup-system || true

# Brave browser repo
dnf5 -y config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
dnf5 -y install brave-origin

systemctl enable podman.socket
systemctl enable greetd.service
systemctl enable flatpak-system-install.service
systemctl enable add-default-user-groups.service
systemctl enable ensure-greetd-greeter.service

### Cleanup build artifacts so they don't ship in the image
dnf5 clean all
rm -rf \
  /run/dnf \
  /run/selinux-policy \
  /run/tuned \
  /var/lib/dnf \
  /var/lib/fprint \
  /var/lib/greetd \
  /var/lib/tuned
