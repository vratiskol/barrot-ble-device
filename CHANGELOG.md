# Changelog

## v0.2.0

- Expand the Barrot BR8554 workaround to skip fragile local-name reads in addition to local extended-feature reads.
- Add a device-specific `BTUSB_BARROT_BR8554` quirk bundle for USB IDs `33fa:0010` and `33fa:0012`.
- Improve module rebuild/install scripts with explicit kernel release handling, seeded build metadata, vermagic validation, and targeted `depmod`.
- Add runtime validation for patched `btusb` modules and Barrot HCI adapter state.
- Refresh patch details and quick-start documentation for the updated workflow.

## v0.1.0

- Add the initial Barrot BR8554 patch set for skipping page-1 local extended-feature reads.
- Add rebuild and install scripts for patched Linux Bluetooth modules.
