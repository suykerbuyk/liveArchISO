#!/bin/sh
set -e
DSK_PREFIX=scsi-35000c50030

SCSI_DEVS="$(ls -1 /dev/disk/by-id/${DSK_PREFIX}* | grep -v part | tr '\n' ' ')"
SD_DEVS="$(ls -lah $SCSI_DEVS | awk -F ' ' '{print $11}' | awk -F '/' '{print "/dev/"$3}' | tr '\n' ' ')"

# echo $SCSI_DEVS
# echo $SD_DEVS
# 
# for DRV in ${SCSI_DEVS}
# do
# 	ls -lah $DRV
# done
# for DRV in ${SD_DEVS}
# do
# 	ls -lah $DRV
# done


for DRV in $SCSI_DEVS
do
	#wipefs -af ${DRV}
	sgdisk --zap-all ${DRV}
	kpartx -sav ${DRV}
	sgdisk  -n1:0:+512M     -t1:ef00 -c1:efi  \
	       	-n2:1052672:+8G -t2:8200 -c2:boot \
		-n3:17829888:0  -t3:bf00 -c3:root ${DRV}
	kpartx -sav ${DRV}
done
partprobe 
read a
for DRV in $SCSI_DEVS
do
	ls ${DRV}-part1
	mkfs.vfat ${DRV}-part1
	mkswap ${DRV}-part2
	kpartx -sav ${DRV}
done
partprobe
ZPOOL_DEVS=$(for DRV in $SCSI_DEVS; do printf "${DRV}-part3 "; done)
zpool create \
	-O atime=off \
	-O acltype=posixacl -O canmount=off -O compression=lz4 \
	-O dnodesize=legacy -O normalization=formD \
	-O xattr=sa -O devices=off -O mountpoint=none \
	-R /mnt rpool raidz2 $ZPOOL_DEVS

zfs create -o canmount=off -o mountpoint=none rpool/ROOT
zfs create -o mountpoint=/ -o canmount=noauto rpool/ROOT/default
zfs create -o mountpoint=none rpool/DATA
zfs create -o mountpoint=/home rpool/DATA/home
zfs create -o mountpoint=/root rpool/DATA/home/root
zfs create -o mountpoint=/local rpool/DATA/local
zfs create -o mountpoint=none rpool/DATA/var
zfs create -o mountpoint=/var/log rpool/DATA/var/log # after a rollback, systemd-journal blocks at reboot without this dataset

zpool set bootfs=rpool/ROOT/default rpool
zfs umount -a
rm -rf /mnt/*
zpool export rpool
zpool import -d /dev/disk/by-id -R /mnt rpool -N
zfs mount rpool/ROOT/default
zfs mount -a

BOOTDEV=0
for DRV in $SCSI_DEVS
do
	mkdir /mnt/boot${BOOTDEV}
	mount ${DRV}-part1 /mnt/boot${BOOTDEV}
	BOOTDEV=$((BOOTDEV +1))
done
