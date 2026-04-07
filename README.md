# Barrot BR8554 Linux Bluetooth Patch Set

This repository packages a small Linux Bluetooth patch set for Barrot BR8554-based USB adapters that hang during controller initialization when the kernel sends `HCI_OP_READ_LOCAL_EXT_FEATURES`.

The consolidated fix adds a USB quirk for device IDs `33fa:0010` and `33fa:0012`, introduces `HCI_QUIRK_BROKEN_LOCAL_EXT_FEATURES`, and skips the offending extended-features read for affected controllers.

## Repository Layout

- `patches/barrot_quirk.patch`: consolidated patch set for direct application
- `patches/bluetooth_core_barrot.patch`: split patch for the HCI quirk definition
- `patches/hci_sync_barrot.patch`: split patch for the sync-path workaround
- `scripts/rebuild_barrot_ble.sh`: apply the consolidated patch and rebuild Bluetooth modules
- `scripts/install_barrot_modules.sh`: install rebuilt modules onto the running system

The rebuild script applies only `patches/barrot_quirk.patch`. The split patches are kept as reference artifacts for review or upstream preparation.

## Requirements

- Linux kernel source tree that matches the target runtime kernel
- `make`, `patch`, and `python3`
- root privileges only for module installation

## Quick Start

Clone this repository and point the scripts at a kernel tree:

```bash
git clone <your-repo-url> barrot-ble-device
cd barrot-ble-device
./scripts/rebuild_barrot_ble.sh --kernel-dir /path/to/linux --no-install
sudo ./scripts/install_barrot_modules.sh --kernel-dir /path/to/linux
```

Or rebuild and install in one step:

```bash
sudo ./scripts/rebuild_barrot_ble.sh --kernel-dir /path/to/linux --install
```

## Notes

- The scripts do not ship or download a kernel tree. They operate on an existing local kernel source/build directory.
- Module installation backs up replaced files under `/lib/modules/$(uname -r)` before writing new ones.
- After installation, reload the Bluetooth stack or reboot.

## Publish to GitHub

After reviewing the files locally:

```bash
git init
git branch -M main
git add .
git commit -m "Initial Barrot BR8554 Bluetooth patch set"
gh repo create barrot-ble-device --public --source=. --remote=origin --push
```
