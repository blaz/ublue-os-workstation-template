# Bluefin OS Development Guide for AI Assistants

This document provides essential knowledge about Bluefin OS, bootc, and the container-based OS workflow for AI assistants working with this codebase.

## Overview

You are working with a **Bluefin OS custom image repository** that uses bootc (bootable containers) to create immutable, container-based operating systems. This is fundamentally different from traditional Linux distributions.

## Key Concepts

### 1. Bluefin OS and Universal Blue

- **Bluefin OS** is a cloud-native desktop operating system built on Fedora Atomic
- **Universal Blue** is not a distribution but a manufacturing process for creating custom OS images
- Base image: `ghcr.io/ublue-os/bluefin:stable` (as seen in Containerfile:6)
- Uses OCI container images for OS delivery, not traditional packages

### 2. bootc (Bootable Containers)

- **bootc** enables "transactional, in-place operating system updates using OCI/Docker container images"
- The container image includes a Linux kernel that boots the system
- At runtime, the OS is NOT running in a container - systemd is pid1 as normal
- Updates are atomic: the entire OS image is replaced as a unit
- Commands:
  - `sudo bootc status` - Check current image
  - `sudo bootc switch ghcr.io/<user>/<image>` - Switch to a different image
  - `sudo bootc upgrade` - Update to latest version of current image

### 3. Immutable OS Architecture

- System directories are read-only except `/etc` and `/var`
- Software installation happens at build time via Containerfile
- No `apt` or `yum install` on the running system - use containers or Flatpaks
- Changes require rebuilding and pushing a new image

## Development Workflow

### 1. Making Changes

1. **Edit `build_files/build.sh`** to:
   - Install packages via `dnf5 install`
   - Enable systemd services
   - Add COPR repositories
   - Configure system settings

2. **Modify `Containerfile`** only to:
   - Change base image
   - Add new build stages
   - Modify build process

3. **Commit and push** changes:
   ```bash
   git add build_files/build.sh
   git commit -m "Add new packages"
   git push
   ```

4. **GitHub Actions** automatically:
   - Builds new container image
   - Signs it with cosign
   - Pushes to ghcr.io registry

5. **Update running system**:
   ```bash
   sudo bootc upgrade
   # or
   sudo bootc switch ghcr.io/<username>/<image>:latest
   ```

### 2. Current Configuration

Based on `build_files/build.sh`, this custom image includes:
- Development tools: `systemd-devel`, `cmake`, `neovim`
- System tools: `tmux`, `mise`, `qemu`, `iotop`
- Audio workstation packages: Wine-TKG, yabridge for Windows VST support
- Services enabled: `podman.socket`, `realtime-setup.service`

### 3. Important Files

- **`Containerfile`**: Defines the container build process
- **`build_files/build.sh`**: Main customization script
- **`.github/workflows/build.yml`**: GitHub Actions workflow for building/publishing
- **`cosign.pub`/`cosign.key`**: Container signing keys (NEVER commit the .key!)
- **`Justfile`**: Local development commands

## Best Practices

### DO:
- Make all software changes in `build.sh`
- Use `dnf5` for package installation (during build only)
- Enable services with `systemctl enable` in build.sh
- Test changes locally with `just build` before pushing
- Keep commits atomic and descriptive
- Use COPR repos for additional software

### DON'T:
- Try to install software on the running system
- Modify system files outside of build process
- Commit `cosign.key` to the repository
- Use `sudo` in build scripts
- Create files in `/usr` at runtime

## Common Tasks

### Adding a Package
```bash
# In build_files/build.sh
dnf5 install -y package-name
```

### Adding a COPR Repository
```bash
# In build_files/build.sh
dnf5 -y copr enable user/repo
dnf5 install -y package-from-copr
dnf5 -y copr disable user/repo  # Disable after install
```

### Enabling a Service
```bash
# In build_files/build.sh
systemctl enable service-name.service
```

### Building Locally
```bash
just build
# or
just build myimage mytag
```

## Container Registry

- Images are published to: `ghcr.io/<github-username>/<repo-name>`
- Tags: `latest`, `latest.YYYYMMDD`, `YYYYMMDD`
- Signed with cosign for security
- Available immediately after GitHub Actions completes

## Debugging

- Check current image: `sudo bootc status`
- View build logs: GitHub Actions tab
- Test build locally: `just build`
- Rollback if needed: `sudo bootc rollback`

## Key Differences from Traditional Linux

1. **No package manager on host** - All software via containers/Flatpaks
2. **Atomic updates** - Entire OS replaced, not individual packages
3. **Git-driven** - Push to git = new OS build
4. **Immutable base** - System files read-only
5. **Container native** - First-class support for Podman/Docker

Remember: You're not managing a Linux system, you're developing a Linux system image that gets deployed atomically.