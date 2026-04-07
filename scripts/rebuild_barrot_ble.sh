#!/bin/bash
# Applies the Barrot BR8554 quirk patch and rebuilds Linux Bluetooth modules.
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: rebuild_barrot_ble.sh [options]

Apply the consolidated Barrot BR8554 patch set to a Linux kernel tree and
rebuild the Bluetooth modules.

Options:
  --kernel-dir PATH  Path to the Linux kernel source/build tree. Defaults to
                     the current working directory.
  -j, --jobs N       Number of parallel build jobs. Defaults to detected CPU
                     count.
  --install          Install rebuilt modules after a successful build.
  --no-install       Build only. This is the default.
  --skip-patch       Skip patch application and rebuild an already-patched tree.
  -h, --help         Show this help message.
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
KERNEL_DIR="$(pwd)"
JOBS="${DEFAULT_JOBS}"
DO_INSTALL=0
APPLY_PATCHES=1
PATCH_FILES=(
	"${REPO_ROOT}/patches/barrot_quirk.patch"
)

while (($#)); do
	case "$1" in
		--kernel-dir)
			if (($# < 2)); then
				echo "--kernel-dir requires a value." >&2
				exit 1
			fi
			KERNEL_DIR="$2"
			shift 2
			;;
		-j|--jobs)
			if (($# < 2)); then
				echo "$1 requires a value." >&2
				exit 1
			fi
			JOBS="$2"
			shift 2
			;;
		--install)
			DO_INSTALL=1
			shift
			;;
		--no-install)
			DO_INSTALL=0
			shift
			;;
		--skip-patch)
			APPLY_PATCHES=0
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			echo "Unknown argument: $1" >&2
			usage >&2
			exit 1
			;;
	esac
done

KERNEL_DIR="$(cd "${KERNEL_DIR}" && pwd)"

if [ ! -f "${KERNEL_DIR}/Makefile" ] || [ ! -d "${KERNEL_DIR}/include/net/bluetooth" ]; then
	echo "Kernel tree not found at ${KERNEL_DIR}" >&2
	exit 1
fi

if ! command -v patch >/dev/null 2>&1; then
	echo "The 'patch' command is required." >&2
	exit 1
fi

PYTHON_BIN="${PYTHON:-python3}"
if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
	if command -v python >/dev/null 2>&1; then
		PYTHON_BIN="python"
	else
		echo "Python is required to synchronise Module.symvers." >&2
		exit 1
	fi
fi

apply_patch_file() {
	local patch_file="$1"
	local rel_patch="${patch_file#${REPO_ROOT}/}"

	if patch --dry-run -R -p1 -d "${KERNEL_DIR}" -i "${patch_file}" >/dev/null 2>&1; then
		echo "[*] Patch already applied: ${rel_patch}"
		return 0
	fi

	if ! patch --dry-run -p1 -d "${KERNEL_DIR}" -i "${patch_file}" >/dev/null 2>&1; then
		echo "Failed dry-run for ${rel_patch}. Check the kernel version and source tree state." >&2
		exit 1
	fi

	echo "[*] Applying ${rel_patch}"
	patch --forward -p1 -d "${KERNEL_DIR}" -i "${patch_file}"
}

if [ "${APPLY_PATCHES}" -eq 1 ]; then
	for patch_file in "${PATCH_FILES[@]}"; do
		apply_patch_file "${patch_file}"
	done
else
	echo "[*] Skipping patch application per --skip-patch."
fi

echo "[*] Refreshing configuration (make olddefconfig)"
make -C "${KERNEL_DIR}" olddefconfig >/dev/null

echo "[*] Building patched net/bluetooth modules"
make -C "${KERNEL_DIR}" -j"${JOBS}" M=net/bluetooth modules

ROOT_SYMVERS="${KERNEL_DIR}/Module.symvers"
NET_SYMVERS="${KERNEL_DIR}/net/bluetooth/Module.symvers"
if [ ! -f "${ROOT_SYMVERS}" ]; then
	echo "Expected ${ROOT_SYMVERS} missing after build" >&2
	exit 1
fi
if [ ! -f "${NET_SYMVERS}" ]; then
	echo "Expected ${NET_SYMVERS} missing after build" >&2
	exit 1
fi

echo "[*] Synchronising symbol CRCs for net/bluetooth exports"
"${PYTHON_BIN}" - "${ROOT_SYMVERS}" "${NET_SYMVERS}" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
net = Path(sys.argv[2])

net_entries = {}
for line in net.read_text().splitlines():
    if not line.strip():
        continue
    parts = line.split("\t")
    if len(parts) < 3:
        continue
    net_entries[parts[1]] = line

updated = []
seen = set()
for line in root.read_text().splitlines():
    if not line.strip():
        continue
    parts = line.split("\t")
    if len(parts) < 3:
        updated.append(line)
        continue
    symbol = parts[1]
    module = parts[2]
    if module == "net/bluetooth/bluetooth" and symbol in net_entries:
        if symbol not in seen:
            updated.append(net_entries[symbol])
            seen.add(symbol)
    else:
        updated.append(line)

for symbol, line in net_entries.items():
    if symbol not in seen:
        updated.append(line)

root.write_text("\n".join(updated) + "\n")
PY

echo "[*] Building patched drivers/bluetooth modules"
make -C "${KERNEL_DIR}" -j"${JOBS}" M=drivers/bluetooth modules

if [ "${DO_INSTALL}" -eq 1 ]; then
	echo "[*] Installing rebuilt Bluetooth modules"
	"${SCRIPT_DIR}/install_barrot_modules.sh" --kernel-dir "${KERNEL_DIR}"
	echo "[*] Installation complete. Reload Bluetooth modules or reboot to activate."
else
	echo "[*] Build complete. Skipped installation per --no-install."
fi
