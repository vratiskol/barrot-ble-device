# Barrot BR8554 Linux Bluetooth Patch Set

This repository packages a Linux Bluetooth patch set for Barrot BR8554-based USB adapters that hang during controller initialization when the kernel sends fragile BR/EDR buffer-size, feature, and local-name probes.

The consolidated fix adds a USB quirk bundle for device IDs `33fa:0010` and `33fa:0012`, introduces dedicated quirks for `HCI_OP_READ_BUFFER_SIZE`, local extended features, and local name, and skips the offending startup reads for affected controllers only. New quirk bits are appended to the enum so existing in-kernel quirk numbers remain stable.

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

- A full, unpacked Linux kernel source tree that matches the target runtime kernel
- `make`, `patch`, and `python3`
- root privileges only for module installation

## Quick Start

Clone this repository:

```bash
git clone https://github.com/vratiskol/barrot-ble-device.git barrot-ble-device
cd barrot-ble-device
```

### What `--kernel-dir` means

`--kernel-dir` must point to the **top-level directory of unpacked Linux kernel source code**. That directory must contain all of these paths:

```text
Makefile
drivers/bluetooth/
include/net/bluetooth/
```

It must **not** point to `/boot` or a `/boot/vmlinuz-*` file. A `vmlinuz` file is the compiled kernel image, not source code. On packaged Debian systems, `/lib/modules/$(uname -r)/build` normally points to kernel headers; the script can read configuration and symbol data from those headers automatically, but it still needs the separate full source tree in `--kernel-dir`.

For example, on Debian 13 with a `6.12.*` kernel, install the matching headers, source archive, and build tools, then unpack the source into a user-writable directory:

```bash
sudo apt update
sudo apt install build-essential bc bison flex libssl-dev libelf-dev dwarves \
  "linux-headers-$(uname -r)" linux-source-6.12 patch python3
mkdir -p "$HOME/src"
tar -xaf /usr/src/linux-source-6.12.tar.xz -C "$HOME/src"
```

Replace `6.12` if `uname -r` reports a different kernel source series. The source and headers must correspond to the kernel release for which the modules are being built. If the running kernel came from Debian backports, ensure the matching backports repository is enabled before installing its headers and source package.

Start with a build-only run. This patches and builds inside the source tree but does not replace any system modules:

```bash
./scripts/rebuild_barrot_ble.sh \
  --kernel-dir "$HOME/src/linux-source-6.12" \
  --kernel-release "$(uname -r)" \
  --no-install
```

Only after that succeeds, install the modules as root:

```bash
sudo ./scripts/install_barrot_modules.sh \
  --kernel-dir "$HOME/src/linux-source-6.12" \
  --kernel-release "$(uname -r)"
```

After installation, reboot or reload the Bluetooth modules, then validate:

```bash
./scripts/validate_barrot_runtime.sh
```

## Notes

- `scripts/fetch_kali_linux_rpi_source.sh` can fetch the exact source package for the running Kali Raspberry Pi kernel; the build scripts can also operate on an existing source tree.
- The build script seeds `.config` and `Module.symvers` from `/lib/modules/$(uname -r)/build` by default when available.
- Module installation backs up replaced files under `/lib/modules/$(uname -r)` before writing the matching rebuilt Bluetooth module set. The full set is required because `CONFIG_MODVERSIONS` can change Bluetooth symbol CRCs when the core is rebuilt.
- After installation, reload the Bluetooth stack or reboot.
