#!/bin/bash
# This script is for making automated snapraid sync process more robust.
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
####################################################################################
#
# This script is for making automated snapraid sync (and scrub) process more robust.
# It is intended to be run instead of directly running snapraid and with a removable
# parity disk.
# It makes sure that the intended sources and parity destinations are mount points 
# and actually mounted. It also checks that the parity file can already be found. 
# This prevents snapraid from running and possibly causing problems if one of the 
# disks are unavailable at the time.
#
# You still have to have fstab and snapraid.conf configured.

# CONFIGURATION:
SOURCES_MOUNT="/mnt/source1:/mnt/source2"
PARITY_MOUNT="/mnt/parity1"
PARITY_FILE="$PARITY_MOUNT/parity"

# Variables prefixed with "WANT_" can be left empty for interactive operation
SCRUB_PERCENT="5"              # How many percents to scrub, check snapraid manual for more info
SCRUB_OLDER_THAN="20"          # Only check data that is older than N days
WANT_SCRUB="y"                 # Scrub after syncing to check for bit rot
WANT_CLOSE_DEVICE="y"          # Unmount the device afterwards.
VERIFY_IF_MOUNTED="n"          # Ask if we should continue if the mountpoint is already 
                               # (maybe unexpectedly) available.

# Optional log file (both sync and scrub). Check manual for information about format.
# TODO: not implemented yet
# SNAPRAID_LOGFILE="/mnt/backup/snapraid-%D-%T.log"

# INTERNAL CONFIGURATION:
# Including /usr/local to make sure snapraid can be found in PATH. 
# It's safer to list /usr/local last so binaries there can't override e.g. /usr/bin
PATH="/bin:/sbin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin"
# Other options for all snapraid operations. Can be left empty.
# TODO: not implemented yet
# SNAPRAID_OPTIONS=""

####################################################################################

# Some checks first
if [ "$(id -u)" == 0 ]; then
    echo "NOTICE: Root user is not strictly required for using snapraid."
fi

hash snapraid 2>/dev/null || { 
   echo  "ERROR: snapraid binary not found in PATH" >&2
   exit 1
}

function verify_missing_variables()
{
    if [ -z "$WANT_SCRUB" ]; then
        echo -n "- Scrub data after syncing (Y/n)? "
        read WANT_SCRUB
    fi

    if [ -z "$WANT_CLOSE_DEVICE" ]; then
        echo -n "- Unmount device and remove it from system (Y/n)? "
        read WANT_CLOSE_DEVICE
    fi
}

function mount_parity_device()
{
    echo -n "Mounting parity disk: "

    if ! mountpoint -q "$PARITY_MOUNT"; then
        sudo mount "$PARITY_MOUNT" && echo "OK"
    else 
        echo "Mountpoint is already in use. Device is probably already mounted."

        if [ $VERIFY_IF_MOUNTED == "y" ] || [ $VERIFY_IF_MOUNTED == "Y" ]; then
            echo "Please make sure the correct media is mounted and press enter to continue."
            read
        fi
    fi

    if [ ! -s "$PARITY_FILE" ]; then
        echo "ERROR: Parity file not found or has size of 0, aborting. Did mounting fail?" >&2
        exit 1
    fi
}

function do_scrubbing()
{
    if [ "$WANT_SCRUB" != "n" ] && [ "$WANT_SCRUB" != "N" ]; then
        echo "--------------- SCRUBBING -------------"
        snapraid -p "$SCRUB_PERCENT" -o "$SCRUB_OLDER_THAN" scrub
        echo -e "\n---------------------------------------"
    fi
}

function remove_parity_device()
{
    if [ "$WANT_CLOSE_DEVICE" != "n" ] && [ "$WANT_CLOSE_DEVICE" != "N" ]; then
        echo -n "Unmounting parity disk: "

        if mountpoint -q "$PARITY_MOUNT"; then
            sudo umount "$PARITY_MOUNT" && echo "OK"
        else
            echo "Not mounted, skipping!"
        fi
    fi
}

function ensure_source()
{
    local checkfs="$1"

    if mountpoint -q "$checkfs"; then
        echo "Filesystem $checkfs is ready."
    else
        echo "Filesystem $checkfs is NOT ready!" >&2
        echo "ERROR: Process aborted!" >&2
        exit 1
    fi
}


# MAIN:
verify_missing_variables

IFS=":"
for source in $SOURCES_MOUNT; do
    ensure_source "$source"
done
unset IFS

mount_parity_device
echo -e "\n--------------- SYNCING ---------------"
snapraid sync
return_code=$?
echo -e "\n---------------------------------------"

if [ $return_code -ne 0 ]; then
    echo "ERROR: snapraid sync returned with an error code $return_code" >&2
    echo "Bad bye!"
    remove_parity_device
    exit 1
else
    do_scrubbing
    remove_parity_device
    echo "Good bye!"
fi
