#!/bin/bash
# Validate that Barrot BR8554 USB Bluetooth adapters are usable at runtime.
set -euo pipefail

STRICT=1

usage() {
	cat <<'EOF'
Usage: validate_barrot_runtime.sh [--no-strict]

Checks the loaded btusb module marker, enumerates Barrot 33fa:0010/0012 USB
devices, maps them to hci adapters, and reports whether each controller is up
with a non-zero Bluetooth address.

Options:
  --no-strict  Always exit 0 after printing the report.
  -h, --help   Show this help message.
EOF
}

while (($#)); do
	case "$1" in
		--no-strict)
			STRICT=0
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

status=0
marker_found=0

echo "kernel_release=$(uname -r)"
if modinfo btusb >/dev/null 2>&1; then
	btusb_path="$(modinfo -n btusb)"
	echo "btusb_module=${btusb_path}"
	echo "btusb_vermagic=$(modinfo -F vermagic btusb)"
	if grep -a -q "Barrot BR8554 init quirks" "${btusb_path}"; then
		marker_found=1
		echo "barrot_patch_marker=present"
	else
		echo "barrot_patch_marker=missing"
		status=1
	fi
else
	echo "btusb_module=missing"
	status=1
fi

echo
echo "usb_barrot_devices:"
if command -v lsusb >/dev/null 2>&1; then
	lsusb -d 33fa:0010 || true
	lsusb -d 33fa:0012 || true
else
	echo "  lsusb not found"
fi

find_usb_parent() {
	local path="$1"
	while [ "${path}" != "/" ]; do
		if [ -f "${path}/idVendor" ] && [ -f "${path}/idProduct" ]; then
			printf '%s\n' "${path}"
			return 0
		fi
		path="$(dirname "${path}")"
	done
	return 1
}

echo
echo "barrot_hci_adapters:"
found_hci=0
for hci_path in /sys/class/bluetooth/hci[0-9]*; do
	[ -e "${hci_path}" ] || continue
	hci="$(basename "${hci_path}")"
	case "${hci}" in
		*:*) continue ;;
	esac
	device_path="$(readlink -f "${hci_path}/device")"
	usb_parent="$(find_usb_parent "${device_path}" || true)"
	[ -n "${usb_parent}" ] || continue

	vendor="$(cat "${usb_parent}/idVendor")"
	product="$(cat "${usb_parent}/idProduct")"
	case "${vendor}:${product}" in
		33fa:0010|33fa:0012) ;;
		*) continue ;;
	esac

	found_hci=1
	hciconfig_out="$(hciconfig -a "${hci}" 2>/dev/null || true)"
	address="$(printf '%s\n' "${hciconfig_out}" | sed -n 's/.*BD Address: \([^ ]*\).*/\1/p' | head -1)"
	if [ -z "${address}" ]; then
		address="$(cat "${hci_path}/address" 2>/dev/null || echo unknown)"
	fi
	dev_type="$(cat "${hci_path}/type" 2>/dev/null || echo unknown)"
	flags="$(printf '%s\n' "${hciconfig_out}" | sed -n '/UP RUNNING\|DOWN/p' | head -1 | xargs || true)"
	printf '  %s usb=%s:%s path=%s type=%s address=%s flags="%s"\n' \
		"${hci}" "${vendor}" "${product}" "$(basename "${usb_parent}")" \
		"${dev_type}" "${address}" "${flags}"

	if [ "${address}" = "00:00:00:00:00:00" ] || ! grep -q "UP RUNNING" <<<"${flags}"; then
		status=1
	fi
done

if [ "${found_hci}" -eq 0 ]; then
	echo "  none"
	status=1
fi

echo
echo "recent_barrot_kernel_messages:"
journalctl -k --since "-30 min" --no-pager --grep "Bluetooth: hci|Barrot BR8554" 2>/dev/null | tail -80 || true

if [ "${marker_found}" -eq 1 ] && [ "${status}" -eq 0 ]; then
	echo
	echo "result=ok"
else
	echo
	echo "result=failed"
fi

if [ "${STRICT}" -eq 1 ]; then
	exit "${status}"
fi
