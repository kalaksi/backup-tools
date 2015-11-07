#!/bin/bash
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

SNAPSHOT_COUNT=3
VOL_SIZE="200G"
VG_NAME="$1"
LV_NAME="$2"

# Exit on any errors
set -e 

if [ -z "$VG_NAME" ] || [ -z "$LV_NAME" ]; then
    echo "Usage: $0 vg_name lv_name"
    exit 1
fi

for ((i=$SNAPSHOT_COUNT; i>0; i--)); do
    snapshot_name="${LV_NAME}_snapshot_${i}"
    snapshot_path="/dev/${VG_NAME}/${snapshot_name}"

    # If block device exists
    if [ -b "$snapshot_path" ]; then
        if [ $i -eq $SNAPSHOT_COUNT ]; then
            echo "* Removing oldest snapshot:" 
            /sbin/lvremove --force "$snapshot_path"
        else
            new_path="/dev/${VG_NAME}/${LV_NAME}_snapshot_$((i+1))"
            echo "* Rotating snapshots:"
            /sbin/lvrename "$snapshot_path" "$new_path"
        fi
    fi
done

echo "* Creating a new snapshot ($VOL_SIZE):"
/sbin/lvcreate -L "$VOL_SIZE" -s -n "$snapshot_name" "/dev/${VG_NAME}/${LV_NAME}"
