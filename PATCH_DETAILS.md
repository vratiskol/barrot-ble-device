# Barrot BR8554 Patch Details

## Purpose

This document describes the full Linux Bluetooth patch set in this repository and the exact behavior it changes for Barrot BR8554-based USB adapters.

The patch exists because some BR8554 adapters fail during controller initialization when the kernel asks for local extended feature information. The failure prevents the controller from completing normal bring-up.

## Affected Hardware

The patch is scoped to the following USB IDs:

- `33fa:0010`
- `33fa:0012`

Barrot is a China-based wireless/Bluetooth brand. Official site:
<https://en.barrot.com.cn/>.

No other adapters are matched by this patch.

## Problem Statement

During initialization, the Linux Bluetooth stack sends `HCI_OP_READ_LOCAL_EXT_FEATURES` to discover additional controller feature pages. On the affected Barrot BR8554 devices, that request does not complete successfully. The controller stalls or times out instead of returning a valid response, which leaves initialization incomplete.

The patch fixes that by marking the affected devices with a dedicated quirk and skipping the failing extended-features read for those devices only.

## Visual Overview

### 1. Failure Path Diagram

```mermaid
flowchart TD
    A[USB adapter 33fa:0010 or 33fa:0012] --> B[btusb binds to controller]
    B --> C[Normal HCI init starts]
    C --> D[Kernel sends HCI_OP_READ_LOCAL_EXT_FEATURES]
    D --> E[BR8554 fails to answer correctly]
    E --> F[Init stalls or times out]
```

### 2. Patched Flow Diagram

```mermaid
flowchart TD
    A[USB adapter 33fa:0010 or 33fa:0012] --> B[btusb quirks_table match]
    B --> C[BTUSB_BROKEN_LOCAL_EXT_FEATURES]
    C --> D[btusb_probe sets HCI_QUIRK_BROKEN_LOCAL_EXT_FEATURES]
    D --> E[hci_read_local_ext_features_1_sync]
    E --> F{Quirk set?}
    F -->|yes| G[Return 0]
    G --> H[Skip page-1 local ext features read]
    H --> I[Controller init continues]
```

### 3. Patch Wiring Schema

| Layer | File | Added symbol or logic | Role |
| --- | --- | --- | --- |
| USB driver | `drivers/bluetooth/btusb.c` | `BTUSB_BROKEN_LOCAL_EXT_FEATURES` | Device-specific match flag |
| USB driver | `drivers/bluetooth/btusb.c` | `33fa:0010`, `33fa:0012` in `quirks_table[]` | Limits scope to known BR8554 IDs |
| HCI core | `include/net/bluetooth/hci.h` | `HCI_QUIRK_BROKEN_LOCAL_EXT_FEATURES` | Named quirk bit visible to core logic |
| HCI sync path | `net/bluetooth/hci_sync.c` | early return in `hci_read_local_ext_features_1_sync()` | Prevents the failing read from being sent |

## Files Changed by the Consolidated Patch

The direct-apply patch is [`patches/barrot_quirk.patch`](/data/barrot/patches/barrot_quirk.patch). It modifies three kernel files:

| Kernel file | Change | Effect |
| --- | --- | --- |
| `drivers/bluetooth/btusb.c` | Adds a new USB-side driver flag and matches the affected USB IDs | Marks BR8554 adapters as needing special handling |
| `include/net/bluetooth/hci.h` | Adds a new HCI quirk definition | Gives the core stack a named quirk for this behavior |
| `net/bluetooth/hci_sync.c` | Skips the failing read when the quirk is present | Lets initialization continue instead of timing out |

## Detailed Change Breakdown

### 1. `drivers/bluetooth/btusb.c`

The patch adds a new `driver_info` bit:

- `BTUSB_BROKEN_LOCAL_EXT_FEATURES`

That flag is then attached to the Barrot device IDs in `quirks_table[]`:

- `USB_DEVICE(0x33fa, 0x0010)`
- `USB_DEVICE(0x33fa, 0x0012)`

When `btusb_probe()` runs, the patch checks whether the matched device carries that flag. If it does, the driver sets:

- `HCI_QUIRK_BROKEN_LOCAL_EXT_FEATURES`

This is the bridge between USB device identification and the HCI-layer workaround. Without this step, the core stack would have no way to know that the controller needs the read skipped.

### 2. `include/net/bluetooth/hci.h`

The patch introduces a new HCI quirk enum entry:

- `HCI_QUIRK_BROKEN_LOCAL_EXT_FEATURES`

The comment added with the enum makes the intent explicit:

- the affected controllers are non-compliant for this operation
- they time out when `HCI_OP_READ_LOCAL_EXT_FEATURES` is issued
- the quirk exists to skip that read and allow initialization to finish

This change is purely definitional, but it is necessary so the rest of the stack can test a stable, named quirk bit instead of using device-specific logic deep in the core code.

### 3. `net/bluetooth/hci_sync.c`

The patch modifies:

- `hci_read_local_ext_features_1_sync(struct hci_dev *hdev)`

New behavior:

```c
if (hci_test_quirk(hdev, HCI_QUIRK_BROKEN_LOCAL_EXT_FEATURES))
	return 0;
```

If the controller has the new quirk, the function returns success immediately instead of calling:

```c
hci_read_local_ext_features_sync(hdev, 0x01);
```

That means the stack does not issue the page-1 extended-features read that triggers the BR8554 initialization failure.

## Component Graph

```mermaid
graph LR
    USBID[USB ID match<br/>33fa:0010 / 33fa:0012]
    BTUSB[btusb.c]
    HCIHDR[hci.h]
    HCISYNC[hci_sync.c]
    INIT[Bluetooth controller init]

    USBID --> BTUSB
    BTUSB -->|sets| HCIHDR
    HCIHDR -->|defines quirk checked by| HCISYNC
    HCISYNC -->|skips HCI_OP_READ_LOCAL_EXT_FEATURES| INIT
```

## Runtime Flow

### Before the patch

1. `btusb` binds to the USB device.
2. Normal HCI initialization proceeds.
3. The stack attempts the local extended-features read.
4. The affected BR8554 controller does not handle that request correctly.
5. Initialization stalls or times out.

### After the patch

1. `btusb` matches `33fa:0010` or `33fa:0012`.
2. `btusb_probe()` sets `HCI_QUIRK_BROKEN_LOCAL_EXT_FEATURES`.
3. The HCI sync path reaches `hci_read_local_ext_features_1_sync()`.
4. The quirk check short-circuits the call.
5. Initialization continues without sending the failing request.

### Before vs After Sequence

```mermaid
sequenceDiagram
    participant U as USB device
    participant B as btusb
    participant H as HCI sync path

    rect rgb(245, 245, 245)
        Note over U,H: Before patch
        U->>B: enumerate
        B->>H: continue normal init
        H->>U: HCI_OP_READ_LOCAL_EXT_FEATURES
        U-->>H: timeout or bad response
        H-->>B: init fails
    end

    rect rgb(235, 248, 235)
        Note over U,H: After patch
        U->>B: enumerate
        B->>H: set HCI_QUIRK_BROKEN_LOCAL_EXT_FEATURES
        H-->>H: detect quirk
        H-->>U: skip extended-features read
        H-->>B: init continues
    end
```

## Scope and Tradeoffs

- The workaround is limited to the two known Barrot USB IDs.
- No behavior changes are introduced for unrelated Bluetooth controllers.
- The patch avoids a specific initialization request instead of changing firmware, transport settings, or generic HCI behavior.
- The tradeoff is that the kernel does not fetch that extended feature page for the affected devices.
- The patch prefers successful controller bring-up over querying a feature page that these controllers fail to report correctly.

## Repository Artifacts

This repository contains one consolidated patch and two reference split patches:

- [`patches/barrot_quirk.patch`](/data/barrot/patches/barrot_quirk.patch): full direct-apply patch
- [`patches/bluetooth_core_barrot.patch`](/data/barrot/patches/bluetooth_core_barrot.patch): HCI quirk definition in `hci.h`
- [`patches/hci_sync_barrot.patch`](/data/barrot/patches/hci_sync_barrot.patch): sync-path guard in `hci_sync.c`

The consolidated patch is the one applied by the rebuild script. The split reference patches capture the HCI-layer pieces for review or upstream preparation; the USB ID matching and probe wiring remain in the consolidated patch.

## Build and Install Path

The scripts in this repository implement the patch workflow around the consolidated patch:

- [`scripts/rebuild_barrot_ble.sh`](/data/barrot/scripts/rebuild_barrot_ble.sh)
- [`scripts/install_barrot_modules.sh`](/data/barrot/scripts/install_barrot_modules.sh)

`rebuild_barrot_ble.sh` performs the following steps:

1. Verifies the target kernel tree looks valid.
2. Applies `patches/barrot_quirk.patch` unless `--skip-patch` is used.
3. Runs `make olddefconfig`.
4. Rebuilds `net/bluetooth` modules.
5. Synchronizes `Module.symvers` CRC entries for Bluetooth exports.
6. Rebuilds `drivers/bluetooth` modules.
7. Optionally installs the rebuilt modules.

`install_barrot_modules.sh` then:

1. Verifies the rebuilt module artifacts exist.
2. Requires root privileges.
3. Backs up existing installed Bluetooth modules under `/lib/modules/$(uname -r)`.
4. Installs the rebuilt modules.
5. Runs `depmod -a`.

## Expected Validation Results

After rebuilding and loading the patched modules, the expected result is:

- the BR8554 adapter enumerates under `btusb`
- controller initialization completes instead of hanging on the extended-features read
- the Bluetooth controller becomes usable from normal user-space tools

Useful validation checks:

- `dmesg` no longer shows the initialization timeout tied to the failing feature read
- `lsusb` shows one of the supported USB IDs
- `hciconfig -a` or `bluetoothctl show` can access the adapter after module reload or reboot

## Summary

The patch is intentionally small and device-specific. It does not attempt to make the BR8554 fully standards-compliant. It only teaches the Linux Bluetooth stack to recognize the affected USB adapters and avoid the one HCI request that breaks their initialization.
