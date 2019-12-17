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
SOURCEVIRTUALDISK="$1"		# e.g. disk3
TARGETIMAGE="$2"			# e.g. ./MASTER_IMAGE.dmg

# check if parameters are exists
if [ -z "$2" ]
then
	echo -e "\nUSAGE: sudo $0 VIRTUALDISK ImageFile"
	echo -e "Example: sudo $0 disk3 ./MASTER_IMAGE.dmg\n"
	echo -e "Current discs:\n"
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
echo "Please check that ALL local Time Machine snapshots are removed, before you create the backup."
echo "Use the commands 'tmutil listlocalsnapshots <mount_point>' and 'tmutil deletelocalsnapshots <snapshot_date>' to do this."
echo
sleep 3

# unmount source partition
diskutil unmountDisk "/dev/${SOURCEVIRTUALDISK}"

# a simple test it the device of TARGETVIRTUALDISK is not monted on /
if [ -n "`mount | grep /dev/${SOURCEVIRTUALDISK}`" ]
then 
	echo
	echo 'Error: BECAUSE IT LOOKS LIKE SOURCEVIRTUALDISK IS STILL MOUNTED.'
	echo 
	mount | grep "/dev/${SOURCEVIRTUALDISK}"
	echo
	exit -1
fi

# create the backup 
(set -x; hdiutil create "${TARGETIMAGE}" -srcdevice "/dev/${SOURCEVIRTUALDISK}")

# check the backup file
(set -x; asr imagescan --source "${TARGETIMAGE}")

# a message to the user
if [ -e "${TARGETIMAGE}" ]
then
	if [ "`hdiutil attach -noverify ${TARGETIMAGE}  2>&1 | grep 'hdiutil: attach failed'`" != "" ]
	then
		echo -e "\nERROR ON IMAGE ${TARGETIMAGE}. Please create a new one and change the source again !!!\n\n"
	else
		 hdiutil info | grep '^/dev/disk' | awk '{ print $1 }' | head -n 1 | sed 's/\/dev\///g' | xargs hdiutil detach
	fi
	echo
	echo "Backup created."
	echo
	echo "PLEASE CHECK THE RESTORE OF THE IMAGE, NOW. Some images could not be restored, in the past."
	echo "Maybe it helps to remove all local Time Machine snapshots to create better images, in such cases."
	echo	
	ls -l "${TARGETIMAGE}"
else
	echo "ERROR by creating backup. Exit, now."
fi

date

exit 0

