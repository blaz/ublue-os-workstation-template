#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 -y copr enable jdxcode/mise

dnf5 install -y \
	systemd-devel \
	realtime-setup \
	tmux \
	mise \
	qemu \
	iotop \
	unrar \
	ncdu \
	mpv \
	pwgen \
	ripgrep \
	cmake \
	lftp \
	neovim

### Audio workstation START
dnf5 -y copr enable patrickl/wine-tkg
sed -i 'enabled=1/a priority=98' /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:patrickl:wine-tkg.repo
dnf5 clean all
dnf5 install --refresh -y install wine.x86_64 wine.i686 wine-mono mingw32-wine-gecko mingw64-wine-gecko wine-dxvk winetricks yabridge libcurl-gnutls
dnf5 install --allowerasing -y pipewire-wineasio pipewire-jack-audio-connection-kit
### Audio workstation END

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket
systemctl enable realtime-setup.service
systemctl enable realtime-entsk.service
