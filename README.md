<p align="center">
  <a href="https://openimages.cloud/images/gentoo-linux/">
    <img src="https://openimages.cloud/img/og/gentoo-linux.png" alt="Gentoo Linux cloud image for OpenStack and Proxmox" width="720">
  </a>
</p>

<p align="center">
  <a href="https://openimages.cloud/images/gentoo-linux/"><img alt="Latest version" src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fimages.openimages.cloud%2Fgentoo-linux%2Flatest%2FMANIFEST.json&query=%24.version&label=latest&color=2459c4&cacheSeconds=3600"></a>
  <a href="https://github.com/open-img-cloud/gentoo-linux/actions/workflows/release.yml"><img alt="Release" src="https://github.com/open-img-cloud/gentoo-linux/actions/workflows/release.yml/badge.svg"></a>
  <a href="https://openimages.cloud/verify/"><img alt="Signed with Sigstore cosign" src="https://img.shields.io/badge/signed-Sigstore%20cosign-2459c4"></a>
  <a href="https://openimages.cloud/quality/"><img alt="Boot-tested on OpenStack" src="https://img.shields.io/badge/boot--tested-OpenStack-2459c4"></a>
  <a href="LICENSE"><img alt="License GPL-2.0" src="https://img.shields.io/badge/license-GPL--2.0-555"></a>
</p>

<p align="center">
  <a href="https://openimages.cloud/images/gentoo-linux/"><b>Catalog page</b></a> ·
  <a href="https://images.openimages.cloud/gentoo-linux/latest/">Download</a> ·
  <a href="https://openimages.cloud/verify/">Verify</a> ·
  <a href="https://github.com/open-img-cloud/docs">Documentation</a> ·
  <a href="https://github.com/open-img-cloud/gentoo-linux/issues">Report an issue</a>
</p>

Gentoo Linux cloud image (qcow2) for **OpenStack** and **Proxmox**: Gentoo publishes no
maintained cloud image, so this one is built from a fresh stage3 with
[diskimage-builder](https://docs.openstack.org/diskimage-builder/), made ready for both clouds
with the same rules as every [openimages.cloud](https://openimages.cloud) image, signed with
Sigstore cosign and boot-tested on a real OpenStack before it is published.

## At a glance

| | |
|---|---|
| **Upstream** | [Gentoo](https://www.gentoo.org/) amd64 systemd stage3 from [distfiles.gentoo.org](https://distfiles.gentoo.org/releases/amd64/autobuilds/), verified against the Gentoo release key |
| **Profile** | `default/linux/amd64/23.0/systemd`, binary distribution kernel (`gentoo-kernel-bin`) |
| **Default user** | `gentoo`, SSH key only, passwordless `sudo` |
| **Firmware** | BIOS |
| **Format** | qcow2, x86_64, root filesystem grown to the disk at first boot |
| **Version** | `YYYY.MM.DD`, the date of the latest upstream stage3 autobuild, e.g. `2026.11.08` ([all versions](https://images.openimages.cloud/gentoo-linux/versions.json)) |
| **Support** | Rolling release: each image is rebuilt from the latest stage3 |

## Quick start

```sh
# Latest version and its file name, from the signed manifest
M=https://images.openimages.cloud/gentoo-linux/latest/MANIFEST.json
V=$(curl -fsS $M | jq -r .version); F=$(curl -fsS $M | jq -r .filename)
curl -fLO https://images.openimages.cloud/gentoo-linux/$V/$F
```

<details>
<summary><b>OpenStack</b></summary>

```sh
openstack image create --disk-format qcow2 --container-format bare \
  --property os_distro=gentoo \
  --property hw_qemu_guest_agent=yes --property os_admin_user=gentoo \
  --file "$F" "Gentoo Linux $V"
```

The full property set (SCSI disk, multiqueue, quiesced snapshots) is on the
[catalog page](https://openimages.cloud/images/gentoo-linux/) and in
[`index.json`](https://images.openimages.cloud/index.json). To keep images up to date
automatically, use [oic-sync](https://github.com/open-img-cloud/oic-sync).

</details>

<details>
<summary><b>Proxmox VE</b></summary>

The commands to create a cloud-init template from this image are on the
[catalog page](https://openimages.cloud/images/gentoo-linux/).

</details>

<details>
<summary><b>Verify the signature</b></summary>

```sh
curl -fLO https://images.openimages.cloud/gentoo-linux/$V/$F.bundle
cosign verify-blob "$F" --bundle "$F.bundle" \
  --certificate-identity-regexp '^https://github.com/open-img-cloud/\.github/\.github/workflows/build-(libguestfs|dib|nix-flake|freebsd)-image\.yml@' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

</details>

## What this image contains

The image is assembled by [`build/dib-build.sh`](build/dib-build.sh) with the DIB elements
`gentoo`, [`oic-gentoo`](build/elements/oic-gentoo) (local to this repository),
`cloud-init-datasources`, `vm` and `bootloader`:

- a stage3 checked against the Gentoo release key, with the systemd profile and the binary
  distribution kernel (no kernel compile), GRUB as boot loader;
- cloud-init and `openssh-server`, with the datasources config drive first, then the
  metadata service (`ConfigDrive, OpenStack, NoCloud, None`); the cloud-init 24+ units
  (`cloud-init-main`, `cloud-init-network`) are enabled;
- `systemd-networkd` and `systemd-resolved`, with a DHCP fallback on every Ethernet
  interface under the network configuration that cloud-init writes;
- `qemu-guest-agent` (enabled at boot) and `growpart`;
- sshd accepting public keys only (no password, no keyboard-interactive).

Every release must pass the same [runtime contract](https://openimages.cloud/quality/) on
OpenStack: SSH with the injected key, cloud-init finished, DNS, hostname, root filesystem grown,
passwordless `sudo`, IPv6 address and egress.

### Notes

- Gentoo's own `experimental/openstack/` images have not been refreshed since April 2023,
  which is why this image is built from stage3 instead of being republished.
- The build runs DIB in an `ubuntu:24.04` container on a GitHub-hosted runner and takes
  about 30 to 60 minutes, since portage emerges the package set.

## How releases happen

1. Every day at 06:53 UTC a watcher reads Gentoo's latest stage3 manifest and opens a pull
   request that bumps [`VERSION`](VERSION) when a newer stage3 is published.
2. Merging it is all it takes: the release is tagged, built, signed, boot-tested and
   published, then `latest/` and the [catalog](https://openimages.cloud/images/) move to it.

This repository only holds what is specific to Gentoo: [`VERSION`](VERSION),
[`build/dib-build.sh`](build/dib-build.sh), [`build/detect-upstream.sh`](build/detect-upstream.sh),
the [`oic-gentoo`](build/elements/oic-gentoo) element and thin workflows calling the shared
pipeline in [`open-img-cloud/.github`](https://github.com/open-img-cloud/.github).

## License

The build tooling in this repository is under [GPL-2.0](LICENSE). The image keeps the licensing
terms of Gentoo and of each package it contains. Gentoo is a trademark of its owner; this
project is not affiliated with the Gentoo project.
