# Changelog

## v0.3.0

- Skip the BR8554 `HCI_OP_READ_BUFFER_SIZE` probe after live `0x1005` timeouts left affected adapters down with a zero ACL MTU.
- Append new HCI quirk bits at the end of the enum to preserve existing quirk numbering across modules.
- Install the complete matching rebuilt Bluetooth module set because this kernel's `CONFIG_MODVERSIONS` rejects stock transport modules against the rebuilt core.
- Fix runtime marker detection for compressed installed modules and scope recent-log reporting to Barrot HCI adapters.
- Add an exact-version Kali Raspberry Pi source fetch helper using `/data/tmp` by default.
- Clarify that `--kernel-dir` requires unpacked kernel sources, with a safe Debian build-only example and explicit rejection of `/boot` and `vmlinuz` paths.

## v0.2.0

- Expand the Barrot BR8554 workaround to skip fragile local-name reads in addition to local extended-feature reads.
- Add a device-specific `BTUSB_BARROT_BR8554` quirk bundle for USB IDs `33fa:0010` and `33fa:0012`.
- Improve module rebuild/install scripts with explicit kernel release handling, seeded build metadata, vermagic validation, and targeted `depmod`.
- Add runtime validation for patched `btusb` modules and Barrot HCI adapter state.
- Refresh patch details and quick-start documentation for the updated workflow.

## v0.1.0

- Add the initial Barrot BR8554 patch set for skipping page-1 local extended-feature reads.
- Add rebuild and install scripts for patched Linux Bluetooth modules.
