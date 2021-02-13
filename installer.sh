#!/bin/sh
set -e

TGT_HOSTNAME="dac"

ROOT_POOL="${TGT_HOSTNAME}_zroot"
SYS_FS="sys"
DATA_FS="data"
SYS_ROOT="${ROOT_POOL}/${SYS_FS}"
SYS_NAME="arch"

DRY_RUN=0
GO_SLOW=0

DSK_PREFIX=scsi-35000c50030

SCSI_DEVS="$(ls -1 /dev/disk/by-id/${DSK_PREFIX}* | grep -v part | tr '\n' ' ')"
SD_DEVS="$(ls -lah $SCSI_DEVS | awk -F ' ' '{print $11}' | awk -F '/' '{print "/dev/"$3}' | tr '\n' ' ')"

# Set a default locale during install to avoid mandb error when indexing man pages
export LANG=C

# This is required to fix grub's "failed to get canonical path" error
export ZPOOL_VDEV_NAME_PATH=1

# Colors
RED='\033[0;31m'
NC='\033[0m' # No Color

MNT_DIR="/mnt"
archzfs_pgp_key="F75D9D76"
zroot="dac"

# Simple message output
msg() {
        printf "$@\n"
        [[ $GO_SLOW == 1 ]] && sleep 1
        return 0
}
err() {
        printf "$@\n"
        [[ $GO_SLOW == 1 ]] && sleep 1
        exit 1
}
#run a command but first tell the user what its going to do.
run() {
        printf " $@ \n"
        [[ 1 == $DRY_RUN ]] && return 0
        eval "$@"; ret=$?
        [[ $ret == 0 ]] && return 0
        printf " $@ - ERROR_CODE: $ret\n"
        exit $ret
}

zpool destroy ${ROOT_POOL} || true
msg "Zapping"
# vgchange -an &> /dev/null
# mdadm --zero-superblock --force "${1}" &> /dev/null
for DRV in $SCSI_DEVS; do run "sgdisk --zap-all ${DRV}" & done
for job in `jobs -p`; do echo "Waiting for $job to complete"; wait ${job}; done
msg "Partitioning"
for DRV in $SCSI_DEVS
do
	run "sgdisk -n1:0:+512M -t1:EF00 -c1:efi -n2:1052672:+8G \
		-t2:8200 -c2:swap -n3:17829888:0 -t3:bf00 -c3:root ${DRV}" &
done
for job in `jobs -p`; do echo "Waiting for $job to complete"; wait ${job}; done

msg "Partprobing"
for DRV in $SCSI_DEVS; do run "partprobe -s ${DRV}"; done
sleep 1
msg "Formatting boot partitions"
for DRV in $SCSI_DEVS; do run "mkfs.vfat ${DRV}-part1 && mkswap ${DRV}-part2" & done
for job in `jobs -p`; do echo "Waiting for $job"; wait ${job}; done
msg "Probing disk"
for DRV in $SCSI_DEVS; do run "partprobe -s ${DRV}" & done
run "sleep 1"
msg "Displaying Partitions"
ZPOOL_DEVS=$(for DRV in $SCSI_DEVS; do printf "${DRV}-part3 "; done)
msg "Creating ${ROOT_POOL} pool"
run "zpool create -f \
	-O atime=off \
	-O relatime=on \
	-o ashift=12 \
	-O acltype=posixacl -O canmount=off -O compression=lz4 \
	-O dnodesize=legacy -O normalization=formD \
	-O xattr=sa -O devices=off -O mountpoint=none \
	-R ${MNT_DIR} ${ROOT_POOL} raidz2 $ZPOOL_DEVS"

run "zfs create -o mountpoint=none -p ${SYS_ROOT}/${SYS_NAME}"
run "zfs create -o mountpoint=none    ${SYS_ROOT}/${SYS_NAME}/ROOT"
run "zfs create -o mountpoint=/       ${SYS_ROOT}/${SYS_NAME}/ROOT/default"
run "zfs create -o mountpoint=legacy  ${SYS_ROOT}/${SYS_NAME}/home"
run "zfs create -o canmount=off -o mountpoint=/var     -o xattr=sa ${SYS_ROOT}/${SYS_NAME}/var"
run "zfs create -o canmount=off -o mountpoint=/var/lib -o xattr=sa ${SYS_ROOT}/${SYS_NAME}/var/lib"
run "zfs create -o canmount=off -o mountpoint=/var/lib/systemd -o xattr=sa ${SYS_ROOT}/${SYS_NAME}/var/lib/systemd"
run "zfs create -o canmount=off -o mountpoint=/usr     -o xattr=sa ${SYS_ROOT}/${SYS_NAME}/usr"

SYSTEM_DATASETS="var/lib/systemd/coredump \
	var/log\
	var/lib/lxc\
	var/lib/lxd\
	var/lib/machines\
	var/lib/libvirt\
	var/cache\
	usr/local"
for ds in ${SYSTEM_DATASETS}; do run "zfs create -o mountpoint=legacy ${SYS_ROOT}/${SYS_NAME}/${ds}"; done
run "zfs create -o mountpoint=legacy -o acltype=posixacl ${SYS_ROOT}/${SYS_NAME}/var/log/journal"

#run "zpool set bootfs=${ROOT_POOL}/ROOT/default ${ROOT_POOL}"
run "zfs umount -a"
run "rm -rf ${MNT_DIR}/*"
run "zpool export ${ROOT_POOL}"

if [[ -e /etc/zfs/zpool.cache ]]
then
	run "rm /etc/zfs/zpool.cache"
else
	msg "no zpool cache file"
fi
run "zpool import -d /dev/disk/by-id -R ${MNT_DIR} ${ROOT_POOL} -N"
run "zpool set cachefile=/etc/zfs/zpool.cache ${ROOT_POOL}"
run "zfs mount ${SYS_ROOT}/${SYS_NAME}/ROOT/default"
for FS in $(zfs list | grep legacy | awk -F ' ' '{print $1}' | sort);  do
       MNTFS=$(echo $FS | sed s@${SYS_ROOT}/${SYS_NAME}/@@g)
       run "mkdir -p  ${MNT_DIR}/${MNTFS}"
       run "mount -t zfs $FS ${MNT_DIR}/${MNTFS}"
done
run "zfs mount -a"
run "mkdir ${MNT_DIR}/etc"
run "mkdir ${MNT_DIR}/root"
BOOTDEV=0
for DRV in $SCSI_DEVS
do
	echo working on installing boot loader in $BOOTDEV $DRV
	if [[ $BOOTDEV == 0 ]] ; then
		run "mkdir ${MNT_DIR}/boot"
		run "mount ${DRV}-part1 ${MNT_DIR}/boot"
	else
		run "mkdir ${MNT_DIR}/boot${BOOTDEV}"
		run "mount ${DRV}-part1 ${MNT_DIR}/boot${BOOTDEV}"
	fi
	BOOTDEV=$((BOOTDEV +1))
done

run "genfstab -U -p ${MNT_DIR} >> ${MNT_DIR}/etc/fstab"
echo 'HOOKS="base udev autodetect modconf block keyboard zfs usr filesystems shutdown"'>>${MNT_DIR}/etc/mkinitcpio.conf
echo "${TGT_HOSTNAME} >${MNT_DIR}/etc/hostname"
run "cp ./pacman.conf ${MNT_DIR}/etc/"
run "cp ./packages.x86_64 ${MNT_DIR}/root/"
run "pacstrap  ${MNT_DIR} base base-devel"
run "arch-chroot ${MNT_DIR}  pacman-key -r DDF7DB817396A49B2A2723F7403BD972F75D9D76"
run "arch-chroot ${MNT_DIR}  pacman-key --lsign-key DDF7DB817396A49B2A2723F7403BD972F75D9D76"
arch-chroot ${MNT_DIR}  pacman -Syu --noconfirm $(cat packages.x86_64 | grep -v '#')
