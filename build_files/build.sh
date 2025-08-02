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
	wev \
	neovim \
	rtkit \
	tuned \
	tuned-profiles-realtime

### Audio workstation START
dnf5 -y copr enable patrickl/wine-tkg
sed -i 'enabled=1/a priority=98' /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:patrickl:wine-tkg.repo
dnf5 clean all
dnf5 install --refresh -y wine.x86_64 wine.i686 wine-mono mingw32-wine-gecko mingw64-wine-gecko wine-dxvk winetricks yabridge libcurl-gnutls
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
systemctl enable tuned.service

### Audio optimization configuration START

# Create realtime group if it doesn't exist
groupadd -f realtime

# Configure kernel parameters for audio (threadirqs)
if ! grep -q "threadirqs" /etc/default/grub; then
    sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 threadirqs"/' /etc/default/grub
fi

# Set tuned profile to realtime
mkdir -p /etc/tuned
echo "realtime" > /etc/tuned/active_profile

# Create PipeWire low-latency configuration
mkdir -p /etc/pipewire/pipewire.conf.d/
cat > /etc/pipewire/pipewire.conf.d/99-lowlatency.conf <<'EOF'
context.properties = {
    default.clock.rate = 48000
    default.clock.allowed-rates = [ 44100 48000 88200 96000 ]
    default.clock.quantum = 256
    default.clock.min-quantum = 32
    default.clock.max-quantum = 8192
}

stream.properties = {
    node.latency = 256/48000
}
EOF

# Create script to prevent apps from stealing realtime priority
mkdir -p /usr/local/bin
cat > /usr/local/bin/audio-rt-prio-fix.sh <<'EOF'
#!/bin/bash
# Script by Robbert (yabridge developer) to prevent apps from stealing RT priority
# Run this before starting your DAW

thread_blacklist_re='^(webrtc_audio_mo|InotifyEventThr)$'
process_blacklist_re='^/usr/lib/(firefox|signal-)'

realtime_threads=$(ps hxH -u "$USER" -o tid:30,rtprio:30,comm:30,command |
    awk '$2 != "-" {
        match($0, /^[ ]*([0-9]+)[ ]+([0-9]+)[ ]+(.{30})(.*)$/, fields)
        tid = fields[1]
        rtprio = fields[2]
        comm = fields[3]
        gsub(/[ ]+$/, "", comm)
        command = fields[4]
        gsub(/^[ ]+/, "", command)
        
        if (comm ~ THREAD_RE || command ~ PROCESS_RE) {
            print "x\t" tid "\t" rtprio "\t" comm "\t" command
        } else {
            print "\t" tid "\t" rtprio "\t" comm "\t" command
        }
    }' THREAD_RE="$thread_blacklist_re" PROCESS_RE="$process_blacklist_re" |
    column -ts$'\t')

need_rescheduling=$(echo "$realtime_threads" | awk '$1 == "x" { print $3 }')
echo "$realtime_threads"

if [[ -z $need_rescheduling ]]; then
    echo
    echo "No threads need rescheduling"
else
    echo
    echo "Rescheduling threads..."
    echo "$need_rescheduling" | xargs -I{} chrt -v -o -p 0 {}
fi
EOF
chmod +x /usr/local/bin/audio-rt-prio-fix.sh

# Create systemd service to add users to realtime group on first boot
cat > /etc/systemd/system/add-user-to-realtime.service <<'EOF'
[Unit]
Description=Add primary user to realtime group
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'for user in $(getent passwd | awk -F: "$3 >= 1000 && $3 < 60000 {print $1}"); do usermod -a -G realtime $user; done'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl enable add-user-to-realtime.service

### Audio optimization configuration END
