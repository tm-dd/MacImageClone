# MacImageClone
This scripts allows to backup and restore an macOS system with APFS file system.
I used it successfully with some old and new Macs with images from macos 10.14 and 10.15.

The benefit to use this scripts instead of an MDM server is the much faster installation of big system (image with more than 100 GB).

It works with new MacBook Pros with M2 Security Chip also, but by upgrading the system
the first boot of the new macOS needs to download and reinstall macOS from the internet.
This will not remove the system from the image, but it take some extra time.

How to use:
- To BACKUP an Mac, list (tmutil listlocalsnapshots /) and remove (tmutil deletelocalsnapshots DATE) all local Time Machine backups on the master Mac, at first. Then shutdown the master Mac and start it on the Target Disk Mode. Now use an other mac to save the virtual disk of the master Mac with the backup script. I use an Thunderbolt cable for the connection between the master Mac and the other Mac with is saving the image.
- For the RESTORING use the restore script in the same way like the backup process and install the new client, running in the Target Disk Mode. If the client has an Apple M2 Security Chip, unlook the old system by connecting with the running macOS. Otherwise the running macOS could not write on the disk of the Mac with the Apple M2 Security Chip, later.

PLEASE NOTE, YOU USE THE SCRIPTS ON YOUR OWN RISK.

Thomas Mueller <><
