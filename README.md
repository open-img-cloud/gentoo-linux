<div id="top"></div>

<!-- PROJECT SHIELDS -->
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![GPL-2.0 License][license-shield]][license-url]

<!-- PROJECT LOGO -->
<br />
<div align="center">

<h3 align="center">Gentoo Linux Cloud Images</h3>

  <p align="center">
    Cloud-init-ready, signed Gentoo Linux images for OpenStack and
    Proxmox, built fresh from upstream stage3 via DIB
    <br />
    <br />
    <a href="https://github.com/open-img-cloud/gentoo-linux/issues">Report a bug</a>
    ·
    <a href="https://github.com/open-img-cloud/gentoo-linux/issues">Request a feature</a>
  </p>
</div>

## About

This repo builds [Gentoo Linux][gentoo] cloud images **from scratch**
using OpenStack [diskimage-builder][dib]'s `gentoo` element, which
fetches a fresh weekly stage3 from
[distfiles.gentoo.org/releases/amd64/autobuilds][upstream], emerges
the cloud-friendly package set, and produces a bootable qcow2.

We deliberately do **NOT** republish Gentoo's own `experimental/openstack/`
images — those have been stale since April 2023 and are essentially
abandoned. Building from stage3 gives us a fresh kernel + userland on
every release.

The build pipeline is shared with the rest of [`open-img-cloud`][org]:
this repo only ships the `VERSION`, `build/dib-build.sh`,
`build/detect-upstream.sh`, and two thin caller workflows that delegate
to the reusable `build-dib-image.yml` in
[`open-img-cloud/.github`][shared] (`@main`).

## Versioning

`<version>` is the date of the upstream stage3 the build was based on
(`YYYY.MM.DD`, e.g. `2026.05.03`). Same date-based scheme as
alpaquita-linux, since Gentoo is rolling-release with no semver.

The `watch.yml` cron polls Gentoo's `latest-stage3-amd64-openrc.txt`
manifest daily at 06:53 UTC and bumps `VERSION` when a fresher stage3
is published. Tag `v<version>` triggers a release build on top of
that exact stage3.

Gentoo profile pinned: `default/linux/amd64/23.0/no-multilib/systemd`.
Kernel: `sys-kernel/gentoo-kernel-bin` (precompiled, skips the
multi-hour kernel rebuild).

## Where to download

Public CDN, served via Cloudflare in front of an R2 bucket (mirror of
the source-of-truth Garage):

| URL pattern                                                                          | Cache policy                  |
|--------------------------------------------------------------------------------------|-------------------------------|
| `https://images.openimages.cloud/gentoo-linux/<version>/<filename>`                  | `max-age=31536000, immutable` |
| `https://images.openimages.cloud/gentoo-linux/latest/<filename>`                     | `max-age=300`                 |

Browse: [images.openimages.cloud/gentoo-linux/latest/][latest]

Filename: `gentoo-<version>-x86_64.qcow2` (e.g.
`gentoo-2026.05.03-x86_64.qcow2`).

## Verify before deploy

cosign 3.x:

```sh
sha256sum -c <filename>.sha256                    # integrity
cosign verify-blob \
    --bundle <filename>.bundle \
    --new-bundle-format \
    --certificate-identity-regexp '^https://github.com/open-img-cloud/\.github/\.github/workflows/build-dib-image\.yml@' \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com \
    <filename>                                     # provenance
```

The certificate identity points at the **reusable** DIB build workflow
in `open-img-cloud/.github` — that's where GitHub's OIDC binds the SAN
for keyless signing. To tie the artifact back to *this* repo's commit,
also check `MANIFEST.json` (commit, build_url, builder digest).

## How to use

### OpenStack

```sh
# Pull the qcow2 (replace <V> with the desired date, e.g. 2026.05.03)
curl -fLO https://images.openimages.cloud/gentoo-linux/<V>/gentoo-<V>-x86_64.qcow2

openstack image create \
    --disk-format qcow2 --container-format bare \
    --min-disk 10 \
    --file gentoo-<V>-x86_64.qcow2 \
    'Gentoo Linux <V>'
```

### Proxmox VE

```sh
scp gentoo-<V>-x86_64.qcow2 root@proxmox:/var/lib/vz/template/iso/

qm create <VMID> --name gentoo-template --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk <VMID> gentoo-<V>-x86_64.qcow2 <STORAGE>
qm set <VMID> --scsihw virtio-scsi-pci --scsi0 <STORAGE>:vm-<VMID>-disk-0
qm set <VMID> --boot c --bootdisk scsi0
qm set <VMID> --ide2 <STORAGE>:cloudinit
qm set <VMID> --serial0 socket --vga serial0
qm set <VMID> --ciuser gentoo --sshkeys ~/.ssh/authorized_keys --ipconfig0 ip=dhcp
```

## Release flow

1. **`watch.yml`** runs daily 06:53 UTC, calls `build/detect-upstream.sh`
   which parses Gentoo's `latest-stage3-amd64-openrc.txt` manifest and
   emits `YYYY.MM.DD`.
2. If the version differs from the current `VERSION`, the workflow
   opens (or updates) a PR `auto/upstream-bump`.
3. Merging the PR + pushing a `v<VERSION>` tag fires `release.yml`,
   which calls the shared `build-dib-image.yml@main` reusable workflow.
4. The reusable workflow runs `build/dib-build.sh` inside an
   `ubuntu:24.04` container on a GH-hosted ubuntu-latest runner.
   The script pip-installs DIB then runs `disk-image-create gentoo
   cloud-init-datasources vm bootloader`. Build is long (~30-60 min)
   because portage emerges the package set even with binhost.
5. Output qcow2 is signed (cosign keyless), bundled with MANIFEST,
   uploaded to Garage + R2, and Cloudflare cache for `latest/` is
   purged.

## Repository layout

```
VERSION                          single line, e.g. "2026.05.03"
build/
  dib-build.sh                   DIB build hook (out_dir as $1, version as $2)
  detect-upstream.sh             parses Gentoo's stage3 manifest
.github/workflows/
  release.yml                    calls build-dib-image.yml on tag push
  watch.yml                      daily cron, calls upstream-watch.yml
.gitignore                       repo-local override for global build/ exclusion
LICENSE                          GPL-2.0
```

## Contributing

Fork, branch, PR. Keep the dib-build script focused on the upstream
DIB element list; complex emerge customisation belongs in a
gentoo-specific element under DIB rather than inline here.

## License

Distributed under the GPL-2.0 License. See `LICENSE`.

## Contact

Kevin Allioli — kevin@stackops.ch · [@stackopshq](https://twitter.com/stackopshq)

Project: [open-img-cloud/gentoo-linux](https://github.com/open-img-cloud/gentoo-linux)

[gentoo]: https://www.gentoo.org/
[upstream]: https://distfiles.gentoo.org/releases/amd64/autobuilds/
[dib]: https://docs.openstack.org/diskimage-builder/
[org]: https://github.com/open-img-cloud
[shared]: https://github.com/open-img-cloud/.github
[latest]: https://images.openimages.cloud/gentoo-linux/latest/

<!-- shields -->
[contributors-shield]: https://img.shields.io/github/contributors/open-img-cloud/gentoo-linux.svg?style=for-the-badge
[contributors-url]: https://github.com/open-img-cloud/gentoo-linux/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/open-img-cloud/gentoo-linux.svg?style=for-the-badge
[forks-url]: https://github.com/open-img-cloud/gentoo-linux/network/members
[stars-shield]: https://img.shields.io/github/stars/open-img-cloud/gentoo-linux.svg?style=for-the-badge
[stars-url]: https://github.com/open-img-cloud/gentoo-linux/stargazers
[issues-shield]: https://img.shields.io/github/issues/open-img-cloud/gentoo-linux.svg?style=for-the-badge
[issues-url]: https://github.com/open-img-cloud/gentoo-linux/issues
[license-shield]: https://img.shields.io/github/license/open-img-cloud/gentoo-linux.svg?style=for-the-badge
[license-url]: https://github.com/open-img-cloud/gentoo-linux/blob/main/LICENSE
