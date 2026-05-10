#!/usr/bin/env bash
# Prints the latest upstream Gentoo stage3 build date on stdout.
#
# Gentoo's `latest-stage3-amd64-openrc.txt` is a PGP-signed manifest
# of the form:
#
#   -----BEGIN PGP SIGNED MESSAGE-----
#   Hash: SHA256
#
#   # Latest as of Sun, 10 May 2026 10:15:01 +0000
#   # ts=1778408101
#   20260503T164604Z/stage3-amd64-openrc-20260503T164604Z.tar.xz 283688292
#   -----BEGIN PGP SIGNATURE-----
#   ...
#
# We extract the first non-comment / non-PGP-marker line, take its
# leading directory segment (e.g. `20260503T164604Z`), strip the time
# part, and reformat YYYYMMDD → YYYY.MM.DD. Same date-based version
# scheme as alpaquita-linux. Git tag: `v<VERSION>`.
#
# Runs in the upstream-watch reusable workflow (no KVM needed) — keep
# it portable bash + curl + awk only.

set -euo pipefail

URL='https://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64-openrc.txt'

manifest=$(curl -fsL "$URL")
if [[ -z "$manifest" ]]; then
  echo "::error::could not fetch $URL" >&2
  exit 1
fi

# Find the first line that looks like `<DATE>T<TIME>Z/stage3-...tar.xz`.
# Skip PGP markers (---*) and comments (^#).
date_iso=$(printf '%s\n' "$manifest" \
  | awk '/^[#-]/ {next} /T[0-9]+Z\/stage3-amd64-openrc/ { split($1,a,"/"); split(a[1],b,"T"); print b[1]; exit }')

if [[ -z "$date_iso" || ! "$date_iso" =~ ^[0-9]{8}$ ]]; then
  echo "::error::could not extract YYYYMMDD from $URL manifest" >&2
  exit 1
fi

# YYYYMMDD → YYYY.MM.DD
printf '%s.%s.%s\n' "${date_iso:0:4}" "${date_iso:4:2}" "${date_iso:6:2}"
