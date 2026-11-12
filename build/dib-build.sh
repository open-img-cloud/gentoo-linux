#!/usr/bin/env bash
# DIB build hook called by the build-dib-image reusable workflow.
# Receives: $1 = output dir, $2 = version (e.g. "2026.05.03").
# Must produce: $1/gentoo-${version}-x86_64.qcow2
#
# Gentoo upstream's `gentoo.osuosl.org/experimental/openstack/` images
# are stale since 2023-04 (essentially abandoned). We build our own
# from a fresh stage3 via DIB's `gentoo` element instead. Profile
# pinned to default/linux/amd64/23.0/no-multilib/systemd which matches
# Gentoo's current stable cloud-friendly profile.
#
# Container expected: ubuntu:24.04 (set by the caller release.yml).
# DIB's gentoo element runs portage operations inside the chroot and
# is independent of the host distro: Ubuntu host works fine.
#
# Build is long: stage3 download + portage tree sync + emerge of the
# minimum set (cloud-init, openssh-server, qemu-guest-agent,
# sys-kernel/gentoo-kernel-bin to skip the kernel compile, grub).
# Expect ~30-60 min on GH-hosted ubuntu-latest.

set -euo pipefail

OUT_DIR="${1:?usage: dib-build.sh <output-dir> <version>}"
VERSION="${2:?usage: dib-build.sh <output-dir> <version>}"

# --- Defaults overridable via env -----------------------------------
# The DIB gentoo element reads GENTOO_PROFILE (not DIB_GENTOO_PROFILE) and
# derives the stage3 from it: ".../23.0/systemd" selects
# latest-stage3-amd64-systemd. It always installs gentoo-kernel-bin (there
# is no variable to change the kernel package); its postinst works again
# with current installkernel (checked 2026-11-11).
GENTOO_PROFILE="${GENTOO_PROFILE:-default/linux/amd64/23.0/systemd}"
# Read by the cloud-init-datasources element (05-set-cloud-init-sources).
DIB_CLOUD_INIT_DATASOURCES="${DIB_CLOUD_INIT_DATASOURCES:-ConfigDrive, OpenStack, NoCloud, None}"

echo "[dib-build] out_dir=$OUT_DIR version=$VERSION"
echo "[dib-build] gentoo profile=$GENTOO_PROFILE datasources=$DIB_CLOUD_INIT_DATASOURCES"

# --- Install build prerequisites (Ubuntu container) -----------------
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  qemu-utils git kpartx debootstrap python3-venv python3-pip \
  ca-certificates jq curl xz-utils e2fsprogs sudo

# --- DIB venv -------------------------------------------------------
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
python3 -m venv "$work/venv"
# shellcheck source=/dev/null
. "$work/venv/bin/activate"
pip install --upgrade pip
pip install diskimage-builder

# --- Build the Gentoo cloud image -----------------------------------
# Same gpgv hardening as octavia in case any sub-debootstrap is invoked
# (the gentoo element doesn't use debootstrap, but cloud-init-datasources
# may pull from apt-style mirrors via curl).
export GENTOO_PROFILE
export DIB_CLOUD_INIT_DATASOURCES
# Local elements shipped in this repo (build/elements/oic-gentoo).
export ELEMENTS_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/elements"
# Stage3 integrity: the element verifies the stage3 against the Gentoo
# release key (extra-data.d/gentoo-releng.gpg).

cd "$work"
# Element list:
#   gentoo                     - base distro (auto-fetches latest stage3)
#   oic-gentoo                 - cloud-init + openssh-server elements,
#                                networkd/resolved, qemu-guest-agent, growpart
#   cloud-init-datasources     - injects datasource_list into the image
#   vm                         - boot+disk wrapper for a bootable qcow2
#   bootloader                 - grub2 install
disk-image-create \
  -a amd64 \
  -t qcow2 \
  --no-tmpfs \
  -o "$OUT_DIR/gentoo-${VERSION}-x86_64" \
  gentoo oic-gentoo cloud-init-datasources vm bootloader

ls -lh "$OUT_DIR/gentoo-${VERSION}-x86_64.qcow2"
echo "[dib-build] done"
