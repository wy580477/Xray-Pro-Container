#!/bin/sh

# The URL of the script project is:
# https://github.com/XTLS/Xray-install

# Modified by wy580477 for customized container <https://github.com/wy580477>

# Gobal verbals

# Xray current version
CURRENT_VERSION=''

# Xray latest release version
RELEASE_LATEST=''

identify_the_operating_system_and_architecture() {
    case "$(uname -m)" in
    'i386' | 'i686')
        MACHINE='32'
        ;;
    'amd64' | 'x86_64')
        MACHINE='64'
        ;;
    'armv7' | 'armv7l')
        MACHINE='arm32-v7a'
        grep Features /proc/cpuinfo | grep -qw 'vfp' || MACHINE='arm32-v5'
        ;;
    'armv8' | 'aarch64')
        MACHINE='arm64-v8a'
        ;;
    'ppc64le')
        MACHINE='ppc64le'
        ;;
    's390x')
        MACHINE='s390x'
        ;;
    *)
        echo "error: The architecture is not supported."
        exit 1
        ;;
    esac
}

get_current_version() {
    # Get the CURRENT_VERSION
    if [[ -f '/usr/bin/xray' ]]; then
        CURRENT_VERSION="$(/usr/bin/xray -version | awk 'NR==1 {print $2}')"
        CURRENT_VERSION="v${CURRENT_VERSION#v}"
    else
        CURRENT_VERSION=""
    fi
}

get_latest_version() {
    # Get Xray latest release version number
    local tmp_file
    tmp_file="$(mktemp)"
    if ! curl -sS -H "Accept: application/vnd.github.v3+json" -o "$tmp_file" 'https://api.github.com/repos/XTLS/Xray-core/releases/latest'; then
        "rm" "$tmp_file"
        echo 'error: Failed to get release list, please check your network.'
        exit 1
    fi
    RELEASE_LATEST="$(sed 'y/,/\n/' "$tmp_file" | grep 'tag_name' | awk -F '"' '{print $4}')"
    if [[ -z "$RELEASE_LATEST" ]]; then
        if grep -q "API rate limit exceeded" "$tmp_file"; then
            echo "error: github API rate limit exceeded"
        else
            echo "error: Failed to get the latest release version."
        fi
        "rm" "$tmp_file"
        exit 1
    fi
    "rm" "$tmp_file"
    RELEASE_LATEST="v${RELEASE_LATEST#v}"
}

download_xray() {
    DOWNLOAD_LINK="https://github.com/XTLS/Xray-core/releases/download/$VERSION/Xray-linux-$MACHINE.zip"
    echo "Downloading Xray archive: $DOWNLOAD_LINK"
    if ! wget -q --no-cache -O "$ZIP_FILE" "$DOWNLOAD_LINK"; then
        echo 'error: Download failed! Please check your network or try again.'
        return 1
    fi
    return 0
    echo "Downloading verification file for Xray archive: $DOWNLOAD_LINK.dgst"
    if ! wget -q --no-cache -O "$ZIP_FILE.dgst" "$DOWNLOAD_LINK.dgst"; then
        echo 'error: Download failed! Please check your network or try again.'
        return 1
    fi
    if [[ "$(cat "$ZIP_FILE".dgst)" == 'Not Found' ]]; then
        echo 'error: This version does not support verification. Please replace with another version.'
        return 1
    fi

    # Verification of Xray archive
    for LISTSUM in 'md5' 'sha1' 'sha256' 'sha512'; do
        SUM="$(${LISTSUM}sum "$ZIP_FILE" | sed 's/ .*//')"
        CHECKSUM="$(grep ${LISTSUM^^} "$ZIP_FILE".dgst | grep "$SUM" -o -a | uniq)"
        if [[ "$SUM" != "$CHECKSUM" ]]; then
            echo 'error: Check failed! Please check your network or try again.'
            return 1
        fi
    done
}

decompression() {
    busybox unzip -q $1 -d "$TMP_DIRECTORY"
    EXIT_CODE=$?
    if [ ${EXIT_CODE} -ne 0 ]; then
        "rm" -r "$TMP_DIRECTORY"
        echo "removed: $TMP_DIRECTORY"
        exit 1
    fi
    echo "info: Extract the Xray package to $TMP_DIRECTORY and prepare it for installation."
}

install_xray() {
    # Install Xray binary to /usr/bin/
    install -m 755 "${TMP_DIRECTORY}/xray" "/usr/bin/xray"
}

identify_the_operating_system_and_architecture

# Two very important variables
TMP_DIRECTORY="$(mktemp -d)"
ZIP_FILE="${TMP_DIRECTORY}/Xray-linux-$MACHINE.zip"

# Install Xray from a local file, but still need to make sure the network is available
if [[ "${INSTALL_VERSION}" = "local" ]]; then
    echo 'warn: Install Xray from a local file.'
    decompression /config/Xray-linux*.zip
else
    get_current_version
    if [[ "${INSTALL_VERSION}" = "latest" ]]; then
        get_latest_version
        VERSION="$RELEASE_LATEST"
        if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
            echo "info: No new version. The current version of Xray is $CURRENT_VERSION ."
            exit 0
        fi
        echo "info: Installing Xray $RELEASE_LATEST for $(uname -m)"
    else
        if [[ "${CURRENT_VERSION}" == "v${INSTALL_VERSION#v}" ]]; then
            echo "info: The current version is same as the specified version. The version is $CURRENT_VERSION ."
            exit 0
        fi
        VERSION="v${INSTALL_VERSION#v}"
        echo "info: Installing specified Xray version $VERSION for $(uname -m)"
    fi
    if ! download_xray; then
        "rm" -r "$TMP_DIRECTORY"
        echo "removed: $TMP_DIRECTORY"
        exit 1
    fi
    decompression "$ZIP_FILE"
fi

install_xray
echo 'installed: /usr/bin/xray'
"rm" -r "$TMP_DIRECTORY"
echo "removed: $TMP_DIRECTORY"
get_current_version
echo "info: Xray $CURRENT_VERSION is installed."
