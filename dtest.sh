#!/bin/sh
set -e


TGT_HOSTNAME="dac"
ZFS_ROOT_POOL="${TGT_HOSTNAME}_zroot"
ZFS_BOOT_POOL="${TGT_HOSTNAME}_zboot"
SYS_FS="sys"
DATA_FS="data"
SYS_ROOT="${ROOT_POOL}/${SYS_FS}"
SYS_NAME="arch" MNT_DIR="/mnt"
TGT_TIME_ZONE="../usr/share/zoneinfo/America/Denver"
archzfs_pgp_key="F75D9D76"

# Set a default locale during install to avoid mandb error when indexing man pages
export LANG=C

# This is required to fix grub's "failed to get canonical path" error
export ZPOOL_VDEV_NAME_PATH=1
declare -a DRV_LIST
declare -a BOOT_PARTS
declare -a SWAP_PARTS
declare -a ROOT_PARTS
declare -a BIOS_PARTS
declare -a EFI_PARTS

# Colors
RED='\033[0;31m'
NC='\033[0m' # No Color
DRY_RUN=0
GO_SLOW=0
LOG_FILE=dtest.log
echo "Start at $(date)" >$LOG_FILE

cat <<- END_OF_PAC_CONF > ./local.pacman.conf
	[options]
	HoldPkg     = pacman glibc
	Architecture = auto
	CheckSpace
	SigLevel    = Required DatabaseOptional
	LocalFileSigLevel = Optional
	[localcacherepo]
	SigLevel = Optional TrustAll
	Server = file:///opt/packages
END_OF_PAC_CONF
#	Server = http://192.168.7.22/

ZFS_BOOT_ATTRS="\
-o ashift=12 \
-d -o feature@async_destroy=enabled \
-o feature@bookmarks=enabled \
-o feature@embedded_data=enabled \
-o feature@empty_bpobj=enabled \
-o feature@enabled_txg=enabled \
-o feature@extensible_dataset=enabled \
-o feature@filesystem_limits=enabled \
-o feature@hole_birth=enabled \
-o feature@large_blocks=enabled \
-o feature@lz4_compress=enabled \
-o feature@spacemap_histogram=enabled \
-O acltype=posixacl \
-O canmount=off \
-O compression=lz4 \
-O devices=off \
-O normalization=formD \
-O relatime=on \
-O xattr=sa "

ZFS_ROOT_ATTRS="\
-o ashift=12 \
-O acltype=posixacl \
-O canmount=off \
-O compression=zstd \
-O dnodesize=auto \
-O normalization=formD \
-O relatime=on \
-O xattr=sa \
-O mountpoint=/ "


# Simple message output
msg() {
        printf "MSG: $@\n" | tee -a $LOG_FILE
        [[ $GO_SLOW == 1 ]] && sleep 1
        return 0
}
err() {
        printf "$@\n" | tee -a $LOG_FILE
        [[ $GO_SLOW == 1 ]] && sleep 1
        exit 1
}
#run a command but first tell the user what its going to do.
run() {
        printf "RUN: $@ \n" | tr '\t' ' ' | sed -r 's/\s+\s/ /g' | tee -a $LOG_FILE
        [[ 1 == $DRY_RUN ]] && return 0
        eval "$@" &>>$LOG_FILE; ret=$?
        [[ $ret == 0 ]] && return 0
        printf " $@ - ERROR_CODE: $ret\n"
        exit $ret
}
# Run stuff in the ZFS chroot install function with optional message
chrun() {
    [[ -n "${2}" ]] && msg "arch-chroot ${2}"
    arch-chroot "${installdir}" /bin/bash -c "${1}"
}

capture_stderr () {
	{ captured=$( { { "$@" ; } 1>&3 ; } 2>&1); } 3>&1
}
capture () {
	if [ "$#" -lt 2 ]; then
		echo "Usage: capture varname command [arg ...]"
		return 1
	fi
	typeset var captured; captured="$1"; shift
    	{ read $captured <<<$( { { "$@" ; } 1>&3 ; } 2>&1); } 3>&1
}

get_disk_list() {
	MENU_FILE=$(mktemp "/tmp/part_menu.XXXXX")
	DEFAULT_DISK_FILTER="XS3840"
	DISK_FILTER="${1:-$DEFAULT_DISK_FILTER}"
	
	declare -a DISK_ARRAY
	for DEV in "$(lsblk -npS -o NAME,VENDOR,MODEL,SIZE)" ; do
		DISK_ARRAY+=("$DEV")
	done
	echo "--clear --checklist \"User the arrows and the space bar to select the drives for the installation system\"" 0 0 5 >${MENU_FILE}
	CNTR=0
	OLD_IFS="${IFS}"
	IFS=$'\n'; for DSK in ${DISK_ARRAY[@]} ; do
		ACTIVE="off"
		if [ "X${DISK_FILTER}" != "X" ]; then
			echo ${DSK} | grep -q "${DISK_FILTER}" && ACTIVE="on"
		fi
		echo "${CNTR} \"${DSK}\" $ACTIVE" >>${MENU_FILE}
		CNTR=$((CNTR+1))
	done
	set +e  #Disable immediate exit on error
	capture_stderr dialog --file ${MENU_FILE}
	RET=$?
	set -e #Reenable immediate exit on error
 	[ $RET -ne 0 ] && echo "Exiting because of cancel: $RET" && return 1
	SELECT=$(echo $captured | tr -d '#')
	[ "X${SELECT}" == "X" ] && echo "Nothing selected, exiting" && return 1
	IFS=' ' read -r -a SELECTIONS <<< "$SELECT"
	for SELECTION in "${SELECTIONS[@]}"; do
		IDX=$(($SELECTION +1))
		DSK=$(echo "{$DISK_ARRAY[@]}" | sed "${IDX}q;d" \
			| awk -F ' ' '{print $1}' \
			| awk -F '/' '{print $3}')
		DEV=$( find /dev/disk/by-id -lname ../../${DSK}\
			| grep -v part | sort -r | head -1)
		DRV_LIST+=($DEV)
	done
	IFS="${OLD_IFS}"
	[ -f "${MENU_FILE}" ] && rm "${MENU_FILE}"
}
prepare_for_start() {
	#for MNT in $(mount -l | grep ${MNT_DIR} ) ; do 
	for MNT in $(cat /proc/mounts | grep ${MNT_DIR} | awk '{print $2}' | sort -r) ; do 
		run "umount ${MNT}" || true
	done
	zpool destroy ${ZFS_BOOT_POOL} || true
	zpool destroy ${ZFS_ROOT_POOL} || true
	msg "Zapping selected disk"
	# vgchange -an &> /dev/null
	# mdadm --zero-superblock --force "${1}" &> /dev/null
	for DRV in  ${DRV_LIST[*]}
	do
		for PART in $(ls ${DRV}* | grep part | sort -r)
		do
			run "wipefs --all ${PART} " &
		done
		for job in `jobs -p`; do echo "* Waiting for job: $job to complete"; wait ${job}; done
		run "sgdisk --zap-all ${DRV} && wipefs --all ${DRV} " &
	done
	for job in `jobs -p`; do echo "* Waiting for job: $job to complete"; wait ${job}; done
	msg "Partitioning"
	for DRV in ${DRV_LIST[*]}
	do
		run "sgdisk -n1:1M:+1G    -t1:EF00  -c1:efi  \
		        -a1 -n5:24k:+100K -t5:EF02  -c5:bios \
		            -n2:0:+4G     -t2:BE00  -c2:boot \
		            -n3:0:-8G     -t3:BF00  -c3:root \
		            -n4:0:0       -t4:8308  -c4:swap ${DRV}" &
	done
	for job in `jobs -p`; do echo "* Waiting for job: $job to complete"; wait ${job}; done
	msg "Partprobing disk"
	for DRV in ${DRV_LIST[*]} 
	do
		run "partprobe -s ${DRV} && udevadm trigger ${DRV}" & 
		EFI_PARTS+=("${DRV}-part1")
		BOOT_PARTS+=("${DRV}-part2")
		ROOT_PARTS+=("${DRV}-part3")
		SWAP_PARTS+=("${DRV}-part4")
		BIOS_PARTS+=("${DRV}-part5")
       	done
	for job in `jobs -p`; do echo "* Waiting for job: $job to complete"; wait ${job}; done
	udevadm trigger
}
create_file_systems() {
	msg "Formatting boot partitions"
	for PART in ${BOOT_PARTS[*]}; do run "mkfs.vfat $PART"  & done
	for job in `jobs -p`; do echo "* Waiting for job: $job to complete"; wait ${job}; done
	msg "Formatting swap partitions"
	for PART in ${SWAP_PARTS[*]}; do run "mkswap $PART"     & done
	for job in `jobs -p`; do echo "* Waiting for job: $job to complete"; wait ${job}; done
	ZFS_VDEVS=""
	for PART in ${ROOT_PARTS[*]}; do ZFS_ROOT_VDEVS+="$PART "; done
	for PART in ${BOOT_PARTS[*]}; do ZFS_BOOT_VDEVS+="$PART "; done
	
	msg "Creating ${ZFS_ROOT_POOL} pool"

	run "zpool create -f ${ZFS_BOOT_ATTRS} -R ${MNT_DIR} ${ZFS_BOOT_POOL} raidz2 $ZFS_BOOT_VDEVS"
	run "zpool create -f ${ZFS_ROOT_ATTRS} -R ${MNT_DIR} ${ZFS_ROOT_POOL} raidz2 $ZFS_ROOT_VDEVS"
	# Create container datasets
	run "zfs create -o canmount=off -o mountpoint=none ${ZFS_BOOT_POOL}/BOOT"
	run "zfs create -o canmount=off -o mountpoint=none ${ZFS_ROOT_POOL}/ROOT"
	run "zfs create -o canmount=off -o mountpoint=none ${ZFS_ROOT_POOL}/DATA"
	# Create root and boot file systems
	run "zfs create -o mountpoint=legacy -o canmount=noauto ${ZFS_BOOT_POOL}/BOOT/default"
	run "zfs create -o mountpoint=/      -o canmount=noauto ${ZFS_ROOT_POOL}/ROOT/default"
	run "zfs mount ${ZFS_ROOT_POOL}/ROOT/default"
	run "mkdir ${MNT_DIR}/boot"
	run "mount -t zfs ${ZFS_BOOT_POOL}/BOOT/default ${MNT_DIR}/boot"

	# Creates datasets within the root file system
	msg "Creating system data sets"
	run "zfs create -o mountpoint=/ -o canmount=off ${ZFS_ROOT_POOL}/DATA/default"
	for i in {usr,var,var/lib}
	do
		run "zfs create -o canmount=off ${ZFS_ROOT_POOL}/DATA/default/$i"
	done
	for i in {home,opt,root,srv,usr/local,var/log,var/spool,var/tmp,var/www}
	do
		run "zfs create -o canmount=on ${ZFS_ROOT_POOL}/DATA/default/$i"
	done
	# Extra zfs file systems for special apps.
	for i in {var/lib/docker,var/lib/nfs,var/lib/lxc,var/lib/libvirt}
	do
		run "zfs create -o canmount=on ${ZFS_ROOT_POOL}/DATA/default/$i"
	done
	run "chmod 750  ${MNT_DIR}/root"
	run "chmod 1777 ${MNT_DIR}/var/tmp"
	msg "Creating first efi system partition"
	# Format and mount EFI system partition
	run "mkfs.vfat -n EFI ${EFI_PARTS[0]}"
	run "mkdir ${MNT_DIR}/boot/efi"
	# We'll tend to the other efi parts later...	
	run "mount -t vfat ${EFI_PARTS[0]} ${MNT_DIR}/boot/efi"
}
generate_mounts() {
# tab-separated zfs properties
# see /etc/zfs/zed.d/history_event-zfs-list-cacher.sh
export \
PROPS="name,mountpoint,canmount,atime,relatime,devices,exec\
,readonly,setuid,nbmand,encroot,keylocation\
,org.openzfs.systemd:requires,org.openzfs.systemd:requires-mounts-for\
,org.openzfs.systemd:before,org.openzfs.systemd:after\
,org.openzfs.systemd:wanted-by,org.openzfs.systemd:required-by\
,org.openzfs.systemd:nofail,org.openzfs.systemd:ignore"

	mkdir -p ${MNT_DIR}/etc/zfs/zfs-list.cache

	zfs list -H -t filesystem -o $PROPS -r ${ZFS_ROOT_POOL} \
	> ${MNT_DIR}/etc/zfs/zfs-list.cache/${ZFS_ROOT_POOL}

	sed -Ei "s|${MNT_DIR}/?|/|" ${MNT_DIR}/etc/zfs/zfs-list.cache/*

	echo ${ZFS_BOOT_POOL}/BOOT/default /boot zfs rw,xattr,posixacl 0 0 >>/${MNT_DIR}/etc/fstab
	echo UUID=$(blkid -s UUID -o value ${EFI_PARTS[0]}) /boot/efi vfat umask=0022,fmask=0022,dmask=0022 0 1 >> ${MNT_DIR}/etc/fstab
}
do_install() {
	pacstrap -C ./local.pacman.conf ${MNT_DIR} $(cat ./packages.x86_64 | grep -v '#')
}

do_configure() {
	msg "Configuring network"
	cat <<- END_OF_NET_CONF > ${MNT_DIR}/etc/systemd/network/20-ethernet.netwok
	#
	# SPDX-License-Identifier: GPL-3.0-or-later

	[Match]
	Name=en*
	Name=eth*

	[Network]
	DHCP=yes
	IPv6PrivacyExtensions=yes

	[DHCP]
	RouteMetric=512
	END_OF_NET_CONF
	msg "Setting hostname to $TGT_HOSTNAME"
	echo $TGT_HOSTNAME>/${MNT_DIR}/etc/hostname 
	msg "Setting time zone to $TGT_TIME_ZONE"
	ln -s $TGT_TIME_ZONE ${MNT_DIR}/etc/localtime
	hwclock --systohc

	msg "Configuring pacman"
	tee -a ${MNT_DIR}/etc/pacman.conf <<- 'PACMAN_CONF'
	[archzfs]
	Include = /etc/pacman.d/mirrorlist-archzfs
	PACMAN_CONF

	tee -a ${MNT_DIR}/etc/pacman.d/mirrorlist-archzfs <<- 'PACMAN_MIRRORS'
	Server = https://archzfs.com/$repo/$arch
	Server = https://mirror.sum7.eu/archlinux/archzfs/$repo/$arch
	Server = https://mirror.biocrafting.net/archlinux/archzfs/$repo/$arch
	Server = https://mirror.in.themindsmaze.com/archzfs/$repo/$arch
	PACMAN_MIRRORS

	msg "Setting language to: $TGT_LANGUAGE"
	echo "en_US.UTF-8 UTF-8" >> ${MNT_DIR}/etc/locale.gen
	echo "LANG=en_US.UTF-8" >> ${MNT_DIR}/etc/locale.conf

	msg "Configuring mkinitcpio"
	mv ${MNT_DIR}/etc/mkinitcpio.conf ${MNT_DIR}/etc/mkinitcpio.conf.original
	tee ${MNT_DIR}/etc/mkinitcpio.conf <<-MKINIT_EOF
	HOOKS=(base udev autodetect modconf block keyboard zfs filesystems)
	MKINIT_EOF

}

get_disk_list
msg "${#DRV_LIST[@]} disk selected"
for DRV in  ${DRV_LIST[*]} ; do
	msg "  $DRV"
done
prepare_for_start
create_file_systems
do_install
generate_mounts
do_configure

# Fix broken grub
ls -lah /dev/disk/by-id/wwn-0x5000c500* | grep part | awk -F '/' '{print $5 "  " $7}' | sed 's/ -> .. //g'  |  while read a; do WWN=$(echo $a | awk -F ' ' '{print $1}'); DEV=$(echo $a | awk -F ' ' '{print $2}'); ln -s /dev/$DEV /dev/$WWN; done

echo "Stop at $(date)" >>$LOG_FILE

