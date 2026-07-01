# Barrot BR8554 Linux Bluetooth Patch Set

This repository packages a Linux Bluetooth patch set for Barrot BR8554-based USB adapters that hang during controller initialization when the kernel sends fragile BR/EDR feature and local-name probes.

The consolidated fix adds a USB quirk bundle for device IDs `33fa:0010` and `33fa:0012`, introduces `HCI_QUIRK_BROKEN_LOCAL_EXT_FEATURES` and `HCI_QUIRK_BROKEN_READ_LOCAL_NAME`, and skips the offending startup reads for affected controllers only.

## Example Hardware

The patch targets USB adapters sold in this general dongle form factor:

[![Example USB Bluetooth dongle](images/barrot-usb-dongle-example.jpg)](https://a.aliexpress.com/_EuhF5xE)

Marketplace reference: <https://a.aliexpress.com/_EuhF5xE>

This image is included as a visual example of the hardware type, not as authoritative vendor documentation for the chipset itself.

## Repository Layout

- `images/barrot-usb-dongle-example.jpg`: marketplace screenshot showing the adapter style
- `patches/barrot_quirk.patch`: consolidated patch set for direct application
- `patches/bluetooth_core_barrot.patch`: split patch for the HCI quirk definition
- `patches/hci_sync_barrot.patch`: split patch for the sync-path workaround
- `scripts/rebuild_barrot_ble.sh`: apply the consolidated patch and rebuild Bluetooth modules
- `scripts/install_barrot_modules.sh`: install rebuilt modules onto the running system
- `scripts/validate_barrot_runtime.sh`: verify the loaded module and Barrot HCI adapter state

The rebuild script applies only `patches/barrot_quirk.patch`. The split patches are kept as reference artifacts for review or upstream preparation.

## Requirements

- Linux kernel source tree that matches the target runtime kernel
- `make`, `patch`, and `python3`
- root privileges only for module installation

## Quick Start

Clone this repository and point the scripts at a prepared Linux kernel source tree that matches the target runtime kernel:

```bash
git clone https://github.com/vratiskol/barrot-ble-device.git barrot-ble-device
cd barrot-ble-device
```

Build and install against the running kernel release:

```bash
./scripts/rebuild_barrot_ble.sh \
  --kernel-dir /path/to/linux \
  --kernel-release "$(uname -r)" \
  --install
```

After installation, reboot or reload the Bluetooth modules, then validate:

```bash
./scripts/validate_barrot_runtime.sh
```

## Notes

- The scripts do not ship or download a kernel tree. They operate on an existing local kernel source/build directory.
- The build script seeds `.config` and `Module.symvers` from `/lib/modules/$(uname -r)/build` by default when available.
- Module installation backs up replaced files under `/lib/modules/$(uname -r)` before writing new ones.
- After installation, reload the Bluetooth stack or reboot.
