#!/bin/bash
# Installs rebuilt Bluetooth modules for the Barrot BR8554 quirk patch set.
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: install_barrot_modules.sh [--kernel-dir PATH]

Install rebuilt Bluetooth modules from a Linux kernel source/build tree into
the currently running system's module directory.

Options:
  --kernel-dir PATH  Path to the Linux kernel source/build tree. Defaults to
                     the current working directory.
  -h, --help         Show this help message.
EOF
}

KERNEL_DIR="$(pwd)"

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

if [ "$(id -u)" -ne 0 ]; then
	echo "This installer must be run as root." >&2
	exit 1
fi

KERNEL_DIR="$(cd "${KERNEL_DIR}" && pwd)"

if [ ! -d "${KERNEL_DIR}/drivers/bluetooth" ] || [ ! -d "${KERNEL_DIR}/net/bluetooth" ]; then
	echo "Kernel tree not found at ${KERNEL_DIR}" >&2
	exit 1
fi

MODULES=(
	"drivers/bluetooth/btusb.ko:/kernel/drivers/bluetooth/btusb.ko"
	"drivers/bluetooth/btbcm.ko:/kernel/drivers/bluetooth/btbcm.ko"
	"drivers/bluetooth/btintel.ko:/kernel/drivers/bluetooth/btintel.ko"
	"drivers/bluetooth/btrtl.ko:/kernel/drivers/bluetooth/btrtl.ko"
	"drivers/bluetooth/hci_uart.ko:/kernel/drivers/bluetooth/hci_uart.ko"
	"net/bluetooth/bluetooth.ko:/kernel/net/bluetooth/bluetooth.ko"
	"net/bluetooth/rfcomm/rfcomm.ko:/kernel/net/bluetooth/rfcomm/rfcomm.ko"
	"net/bluetooth/bnep/bnep.ko:/kernel/net/bluetooth/bnep/bnep.ko"
	"net/bluetooth/hidp/hidp.ko:/kernel/net/bluetooth/hidp/hidp.ko"
	"net/bluetooth/bluetooth_6lowpan.ko:/kernel/net/bluetooth/bluetooth_6lowpan.ko"
)

missing=()
for entry in "${MODULES[@]}"; do
	src_rel=${entry%%:*}
	src="${KERNEL_DIR}/${src_rel}"
	if [ ! -f "${src}" ]; then
		missing+=("${src_rel}")
	fi
done

if [ ${#missing[@]} -gt 0 ]; then
	echo "Missing module artifacts in ${KERNEL_DIR}:" >&2
	for m in "${missing[@]}"; do
		echo "  ${m}" >&2
	done
	echo "Aborting. Rebuild the modules before running the installer." >&2
	exit 1
fi

KERNEL_RELEASE="$(uname -r)"
MODULE_ROOT="/lib/modules/${KERNEL_RELEASE}"
timestamp="$(date +%Y%m%d%H%M%S)"

backup_module() {
	local path="$1"
	if [ -e "${path}" ]; then
		echo "Backing up ${path} -> ${path}.backup-${timestamp}"
		mv "${path}" "${path}.backup-${timestamp}"
	fi
}

install_module() {
	local src="$1"
	local dst="$2"
	local dst_dir
	dst_dir="$(dirname "${dst}")"
	mkdir -p "${dst_dir}"
	backup_module "${dst}"
	backup_module "${dst}.xz"
	install -m 0644 "${src}" "${dst}"
	echo "Installed $(basename "${dst}") in ${dst_dir}"
}

echo "[*] Installing modules built in ${KERNEL_DIR}"
for entry in "${MODULES[@]}"; do
	src_rel=${entry%%:*}
	dst_rel=${entry#*:}
	src="${KERNEL_DIR}/${src_rel}"
	dst="${MODULE_ROOT}${dst_rel}"
	install_module "${src}" "${dst}"
done

depmod -a

echo "depmod completed. Reload modules with:"
echo "  modprobe -r btusb btbcm btintel btrtl rfcomm bnep hidp bluetooth"
echo "  modprobe bluetooth"
echo "  modprobe btbcm btintel btrtl btusb"
