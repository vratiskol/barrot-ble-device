#!/bin/bash
# Fetch the exact Kali linux-rpi source package for the running Raspberry Pi kernel.
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: fetch_kali_linux_rpi_source.sh [options]

Download and unpack the Kali linux-rpi source package that matches the running
linux-image package. The script writes apt source metadata under the destination
directory and does not modify /etc/apt.

Options:
  --dest PATH       Destination directory. Defaults to /data/tmp/barrot-src.
  --package NAME    Source package name. Defaults to linux-rpi.
  --version VER     Source package version. Defaults to installed linux-image
                    version for uname -r.
  --source-line STR deb-src line. Defaults to Kali rolling.
  -h, --help        Show this help message.
EOF
}

DEST="/data/tmp/barrot-src"
PACKAGE="linux-rpi"
VERSION=""
SOURCE_LINE="deb-src http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware"

while (($#)); do
	case "$1" in
		--dest)
			if (($# < 2)); then
				echo "--dest requires a value." >&2
				exit 1
			fi
			DEST="$2"
			shift 2
			;;
		--package)
			if (($# < 2)); then
				echo "--package requires a value." >&2
				exit 1
			fi
			PACKAGE="$2"
			shift 2
			;;
		--version)
			if (($# < 2)); then
				echo "--version requires a value." >&2
				exit 1
			fi
			VERSION="$2"
			shift 2
			;;
		--source-line)
			if (($# < 2)); then
				echo "--source-line requires a value." >&2
				exit 1
			fi
			SOURCE_LINE="$2"
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

if [ -z "${VERSION}" ]; then
	IMAGE_PACKAGE="linux-image-$(uname -r)"
	VERSION="$(dpkg-query -W -f='${Version}' "${IMAGE_PACKAGE}")"
fi

mkdir -p "${DEST}/apt-lists/partial" "${DEST}/apt-cache/archives/partial" "${DEST}/source"
SOURCE_LIST="${DEST}/apt-sources.list"
printf '%s\n' "${SOURCE_LINE}" > "${SOURCE_LIST}"

APT_ARGS=(
	-o "Dir::Etc::sourcelist=${SOURCE_LIST}"
	-o "Dir::Etc::sourceparts=-"
	-o "Dir::State::Lists=${DEST}/apt-lists"
	-o "Dir::Cache=${DEST}/apt-cache"
	-o "APT::Get::List-Cleanup=0"
)

echo "[*] Updating temporary source package indexes"
apt-get "${APT_ARGS[@]}" update

echo "[*] Fetching ${PACKAGE}=${VERSION}"
(
	cd "${DEST}/source"
	apt-get "${APT_ARGS[@]}" source "${PACKAGE}=${VERSION}"
)

echo "[*] Source directories:"
find "${DEST}/source" -maxdepth 1 -type d -name "${PACKAGE}-*" -print
