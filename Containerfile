# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

# Base Image
FROM ghcr.io/ublue-os/base-main:latest
## Other possible base images include:
# FROM ghcr.io/ublue-os/bazzite:testing
# FROM ghcr.io/ublue-os/aurora:stable
# FROM ghcr.io/ublue-os/bluefin-nvidia-open:stable
# 
# ... and so on, here are more base images
# Universal Blue Images: https://github.com/orgs/ublue-os/packages
# Fedora base image: quay.io/fedora/fedora-bootc:44
# CentOS base images: quay.io/centos-bootc/centos-bootc:stream10

### [IM]MUTABLE /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop.
##
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

RUN rm /opt && mkdir /opt

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

# Rebrand system identifiers in /usr/lib/os-release
RUN sed -i \
    -e 's/^ID=.*/ID=fedora/' \
    -e 's/^ID_LIKE=.*/ID_LIKE="fedora"/' \
    -e 's/^NAME=.*/NAME="hurunagus-umbriel"/' \
    -e 's/^PRETTY_NAME=.*/PRETTY_NAME="hurunagus-umbriel"/' \
    -e 's/^VERSION_CODENAME=.*/VERSION_CODENAME=hurunagus-umbriel/' \
    -e 's/^DEFAULT_HOSTNAME=.*/DEFAULT_HOSTNAME="hurunagas33"/' \
    /usr/lib/os-release

# Copy custom Flatpak list into the system configuration path
COPY system-flatpaks.list /usr/share/ublue-os/flatpaks/system-flatpaks.list

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
