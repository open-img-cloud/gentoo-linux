==========
oic-gentoo
==========

openimages.cloud additions for the Gentoo (systemd profile) cloud image:

- packages: qemu-guest-agent, growpart (cloud-init growpart/resizefs);
- network: systemd-networkd and systemd-resolved enabled, with a fallback
  DHCP profile for every ethernet interface (cloud-init renders the
  OpenStack network config for networkd on top of it). The upstream
  dhcp-all-interfaces element only supports OpenRC on Gentoo;
- qemu-guest-agent enabled at boot.
