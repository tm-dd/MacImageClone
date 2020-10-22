#!/bin/bash
#
# Copyright (c) 2019 tm-dd (Thomas Mueller)
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
#

clear
date

# SETTINGS
SOURCEIMAGE="$1"								# e.g. ./MASTER_IMAGE.dmg
TARGETDISK="$2"									# e.g. disk2

# use random temporary name of the new disk volume (the name have to be a new one)
TEMPVOLUMENAME='NewMac-'`date "+%Y%m%d-%H%M%S"`

if [ -z "$2" ]
then
	echo -e "\nUSAGE: sudo $0 SOURCEIMAGE TARGETDISK"
	echo -e "Example: sudo $0 ./MASTER_IMAGE.dmg disk2\n"
	echo -e "Current disks:\n"
	( set -x; diskutil list )
	echo
	exit -1
fi

# check of root rights
if [ $USER != "root" ]
then
	echo "THIS SCRIPT MUST RUN AS USER root OR WITH sudo !!!"
        exit -1
fi

# give a message to the user, about necessary dependencies to the using software
echo
echo "Please note, you should not use this script to backup or restore an macOS version higher then the running system version "`sw_vers | grep 'ProductVersion' | awk '{ print $2 }'`" of macOS."
echo

# print system information about the disk
diskutil list "${TARGETDISK}"
echo
echo "PRESS ENTER TO RESTORE ${TARGETDISK} with the image of ${SOURCEIMAGE}. THIS WILL DELETE ANY FILES ON THE DISK: ${TARGETDISK} !!!"
echo
read

## RESTORE VOLUME for macOS ##

	# wipe the first blocks of the disk (necessary to repartitioning an APFS formated disk)
	echo "Cleaning the first blocks of the disk ${TARGETDISK}, now."
	diskutil unmountDisk ${TARGETDISK}
	sleep 3
	dd if=/dev/zero of=/dev/r"${TARGETDISK}" bs=10m count=100 || ( echo -e "\nERROR: Could not wipe the first 1GB of the disk '${TARGETDISK}'.\nIs some partition of the disk still mounted ?\nPlease CLEAN/WIPE (NOT FORMAT) the disk manually OR (on Macs with Apple T2 Security Chip) eject, mount and unmount the disk and retry the restore !!!\n")
	dd if=/dev/zero of=/dev/r"${TARGETDISK}" bs=10m count=1 || exit -1

    # delete TARGETVOLUME and create APFS volume
    (set -x; diskutil partitionDisk "${TARGETDISK}" GPT APFS "${TEMPVOLUMENAME}" 100% || exit -1)
    
    # activate on-disk ownership (in future maybe use: diskutil enableOwnership ...)
    (set -x; vsdbutil -a "/Volumes/${TEMPVOLUMENAME}")
    
    # clone the partition
    (set -x; asr restore -s "${SOURCEIMAGE}" -t "/Volumes/${TEMPVOLUMENAME}" --erase --noverify; sleep 5)

	# find the new TARGETVIRTUALDISK
	TARGETVIRTUALDISK=`diskutil list "${TARGETDISK}" | grep 'Apple_APFS Container' | awk -F 'Container' '{ print $2 }' | awk -F ' ' '{ print $1 }'`

	# a simple test it the device of TARGETVIRTUALDISK is not monted on /
	if [ "`mount | grep 'on / ' | awk -F 's' '{ print $1 "s" $2 }'`" == "/dev/${TARGETVIRTUALDISK}" ]
	then 
		echo
		echo 'Error: PLEASE CHECK THE CONFIGURATION, BECAUSE IT LOOKS LIKE TARGETDISK IS MOUNTED on "/".'
		echo 
		mount | grep 'on / '
		echo
		exit -1
	fi

## RESTORE VOLUME VM (for the sleepfile) ##

    # add the volume for the VM partition
    (set -x; diskutil apfs addVolume "${TARGETVIRTUALDISK}" apfs VM -role V || exit -1)
    
    # unmount the VM partition
    TARGETVMPART=`mount | grep "${TARGETVIRTUALDISK}" | grep 'VM' | awk -F ' ' '{ print $1 }'`
    TARGETVM=`diskutil info "${TARGETVMPART}" |  grep "Mount Point:" | awk -F ":" '{ print $2 }' | sed -e 's/^[ \t]*//'`
    (set -x; mount; diskutil unmount "${TARGETVM}"; sleep 5; mount; set +x)

## MAKE BOOTABLE

	# Check some files of the new system to make it bootable.
	TARGETVOLUMENAME=`diskutil info "/dev/${TARGETVIRTUALDISK}s1" |  grep "Mount Point:" | awk -F ":" '{ print $2 }' | sed -e 's/^[ \t]*//'`
	while [ ! -d "${TARGETVOLUMENAME}/System/Library/CoreServices" ] || [ "${TARGETVOLUMENAME}" == "" ]
	do
		echo -e "\nSORRY, but could not find: '${TARGETVOLUMENAME}/System/Library/CoreServices' to make the new system bootable."
		echo -n "Please type the path to the new system [e.g. '/Volumes/Macintosh HD' without quotation marks ]: "
		read TARGETVOLUMENAME
	done

    # specify the path to the NEW boot files
    (set -x; bless --folder "${TARGETVOLUMENAME}/System/Library/CoreServices" --bootefi)
    
    # update the dyld's shared cache
    (set -x; update_dyld_shared_cache -root "${TARGETVOLUMENAME}" -force)

    # get infos about the boot settings
    (set -x; bless --info "${TARGETVOLUMENAME}")

    # check the new partitions
    (set -x; diskutil repairVolume "${TARGETVIRTUALDISK}")

	# a message to the user
	echo "Restore finished. Please try to start from the new system."

date

exit 0
