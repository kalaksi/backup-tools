#!/usr/bin/env bash
#
# A tiny script for creating and rotating LVM snapshots for backup purposes
# Copyright (C) 2015 kalaksi@users.noreply.github.com
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
set -eu

# Default values
declare -i SNAPSHOT_COUNT=3
LV_SIZE="50G"
DATE_SUFFIX="$(date +%Y%m%d%H%M%S)"

function _help {
    cat <<EOF
Usage: $0 [-s lvm_compatible_size] [-c snapshot_count_to_keep] vg_name lv_name
Default values are $LV_SIZE and $SNAPSHOT_COUNT respectively.
EOF
    exit 1
}

while getopts ":c:s:" option; do
    case $option in
        s) LV_SIZE="$OPTARG";;
        c) SNAPSHOT_COUNT="$OPTARG";;
        \?) echo $OPTARG; _help;;
    esac
done
shift $((OPTIND - 1))

VG_NAME="${1:-}"
LV_NAME="${2:-}"
LV_PATH="/dev/${VG_NAME}/${LV_NAME}"

if [ -z "$VG_NAME" ] || [ -z "$LV_NAME" ]; then
    _help
fi

if [ "$SNAPSHOT_COUNT" -gt 0 ]; then
    echo "* Creating a new snapshot (size: $LV_SIZE):"
    lvcreate -L "$LV_SIZE" -s -n "${LV_NAME}_snapshot_${DATE_SUFFIX}" "$LV_PATH"
fi

echo "* Removing older snapshots:" 
snapshot_path_glob="${LV_PATH}_snapshot_*"

# Process as long as there are too many snapshots
while [ "$(ls -1q $snapshot_path_glob 2>/dev/null | wc -l)" -gt "$SNAPSHOT_COUNT" ]; do
    # Finds the oldest by simply sorting by names and getting the first one
    oldest_snapshot="$(ls -1q $snapshot_path_glob | head -1)"

    # Just a sanity check
    if [ ! -b "$oldest_snapshot" ]; then
        echo "Error: $oldest_snapshot is not a block device" >&2
        exit 1
    fi

    lvremove -y "$oldest_snapshot"
done
exit 0
