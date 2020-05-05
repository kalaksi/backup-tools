#!/bin/bash
#
# A tiny script for cloning LVM logical volumes. Uses snapshots.
# Copyright (C) 2017 kalaksi@users.noreply.github.com
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Exit on any errors
set -e 
set -u

# Default configuration
TEMP_SNAPSHOT_SIZE="5G"
DATE_SUFFIX="$(date +%Y%m%d%H%M%S)"
TEMP_SNAPSHOT_NAME_SUFFIX="-temp_snapshot-${DATE_SUFFIX}"
LV_NAME_SUFFIX="-clone-${DATE_SUFFIX}"

function _help {
    echo "Clones logical volumes to a destination VG. Destination LV is automatically created if it doesn't exist."
    echo "If the destination LV already exists or is created manually, it should have the exact same size as the source LV."
    echo "It's possible to use snapshots (e.g. with lvm-snapshot-rotation.sh) and re-use previously cloned volumes to achieve incremental backups."
    echo ""
    echo "Usage: $0 [-n name-suffix ] [-s temporary_snapshot_size] source_vg/source_lv destination_vg"
    exit 1
}

function _error {
    echo "${2:-}ERROR: $1" >&2
    exit 1
}

function _verify_block_device {
    # Just a sanity check
    local device="${1:-}"
    if [ ! -b "$device" ]; then
        _error "Error: ${device} is not a block device"
    fi
}

function _cleanup {
    echo "* Cleaning up"
    lvremove -f "$1"
}

# MAIN:

# Need at least one parameter
[ $# -gt 0 ] || _help

while getopts ":n:s:" option; do
    case $option in
        n) LV_NAME_SUFFIX="$OPTARG";;
        s) TEMP_SNAPSHOT_SIZE="$OPTARG";;
        \?) _help;;
    esac
done
shift $((OPTIND - 1))

SOURCE_VG_LV="${1:-}"
DESTINATION_VG="${2:-}"
SOURCE_VG="$(cut -d '/' -f 1 -s <<< $SOURCE_VG_LV)"
SOURCE_LV="$(cut -d '/' -f 2 -s <<< $SOURCE_VG_LV)"
SOURCE_PATH="/dev/${SOURCE_VG_LV}"
DESTINATION_PATH="/dev/${DESTINATION_VG}/${SOURCE_LV}${LV_NAME_SUFFIX}"
TEMP_SNAPSHOT_PATH="/dev/${SOURCE_VG}/${SOURCE_LV}${TEMP_SNAPSHOT_NAME_SUFFIX}"
_verify_block_device "$SOURCE_PATH"
SOURCE_SIZE=$(lvs "$SOURCE_PATH" -o LV_SIZE --noheadings --units b --nosuffix | sed -e 's/^[[:space:]]*//')

if ! type pv &>/dev/null; then
    _error "pv must be installed"
fi

if [ -z "$SOURCE_VG_LV" ] || [ -z "$DESTINATION_VG" ] || \
   [ -z "$SOURCE_LV" ]    || [ -z "$SOURCE_VG" ] || \
   [ -z "$SOURCE_SIZE" ]; then
    _help
fi

_return_value=0

echo "* Preparing to clone LV"
if [ ! -b "$DESTINATION_PATH" ]; then
    echo "  Creating the destination LV:"
    lvcreate -L "${SOURCE_SIZE}b" -n "${SOURCE_LV}${LV_NAME_SUFFIX}" "${DESTINATION_VG}"
fi

DESTINATION_SIZE=$(lvs "$DESTINATION_PATH" -o LV_SIZE --noheadings --units b --nosuffix)
if [ -z "$DESTINATION_SIZE" ] || [ "$DESTINATION_SIZE" -ne "$SOURCE_SIZE" ]; then
    _error "destination LV exists but is different size than source" "  "
fi

echo "  Creating a temporary snapshot (size: $TEMP_SNAPSHOT_SIZE):"
lvcreate -L "$TEMP_SNAPSHOT_SIZE" -s -n "${SOURCE_LV}${TEMP_SNAPSHOT_NAME_SUFFIX}" "$SOURCE_PATH"

echo "* Copying data from ${TEMP_SNAPSHOT_PATH} to ${DESTINATION_PATH})."
# Some time to abort if something seems wrong
sleep 5
_verify_block_device "$TEMP_SNAPSHOT_PATH"
_verify_block_device "$DESTINATION_PATH"
# Continue to cleaning up the temporary snapshot even if copying fails
(dd bs=1M status=none if="$TEMP_SNAPSHOT_PATH" | pv -s "$SOURCE_SIZE" | dd bs=1M status=none conv=fdatasync of="$DESTINATION_PATH") || _return_value=1

_cleanup "$TEMP_SNAPSHOT_PATH"

exit $_return_value
