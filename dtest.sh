#!/bin/sh
set -e


TGT_HOSTNAME="dac"
ROOT_POOL="${TGT_HOSTNAME}_zroot"
SYS_FS="sys"
DATA_FS="data"
SYS_ROOT="${ROOT_POOL}/${SYS_FS}"
SYS_NAME="arch"
MNT_DIR="/mnt"
archzfs_pgp_key="F75D9D76"
zroot="dac"

# Set a default locale during install to avoid mandb error when indexing man pages
export LANG=C

# This is required to fix grub's "failed to get canonical path" error
export ZPOOL_VDEV_NAME_PATH=1
declare -a DRV_LIST
declare -a BOOT_PARTS
declare -a SWAP_PARTS
declare -a ROOT_PARTS

# Colors
RED='\033[0;31m'
NC='\033[0m' # No Color
DRY_RUN=0
GO_SLOW=0

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
# Run stuff in the ZFS chroot install function with optional message
chrun() {
    [[ -n "${2}" ]] && msg "arch-chroot ${2}"
    arch-chroot "${installdir}" /bin/bash -c "${1}"
}

prepare_for_start() {
	for MNT in $(mount -l | grep ${MNT_DIR} ) ; do 
		umount "${MNT}" || true
	done
	zpool destroy ${ROOT_POOL} || true
	msg "Zapping"
	# vgchange -an &> /dev/null
	# mdadm --zero-superblock --force "${1}" &> /dev/null
	for DRV in  ${DRV_LIST[*]} ; do run "sgdisk --zap-all ${DRV}" & done
	for job in `jobs -p`; do echo "Waiting for $job to complete"; wait ${job}; done
	msg "Partitioning"
	for DRV in ${DRV_LIST[*]}
	do
		run "sgdisk -n1:0:+512M -t1:EF00 -c1:efi -n2:1052672:+8G \
			-t2:8200 -c2:swap -n3:17829888:0 -t3:bf00 -c3:root ${DRV}" &
	done
	for job in `jobs -p`; do echo "Waiting for $job to complete"; wait ${job}; done

	msg "Partprobing"
	for DRV in ${DRV_LIST[*]} 
	do
		run "partprobe -s ${DRV}"
		BOOT_PARTS+=("${DRV}-part1")
		SWAP_PARTS+=("${DRV}-part2")
		ROOT_PARTS+=("${DRV}-part3")
       	done
	sleep 1
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
create_file_systems() {
	msg "Formatting boot partitions"
	for PART in ${BOOT_PARTS[*]}; do run "mkfs.vfat $PART"  & done
	for job in `jobs -p`; do echo "Waiting for $job to complete"; wait ${job}; done
	msg "Formatting swap partitions"
	for PART in ${SWAP_PARTS[*]}; do run "mkswap $PART"     & done
	for job in `jobs -p`; do echo "Waiting for $job to complete"; wait ${job}; done
	ZFS_VDEVS=""
	for PART in ${ROOT_PARTS[*]}; do ZFS_VDEVS+="$PART "; done
	
	msg "Creating ${ROOT_POOL} pool"
	run "zpool create -f \
		-O atime=off \
		-O relatime=on \
		-o ashift=12 \
		-O acltype=posixacl -O canmount=off -O compression=lz4 \
		-O dnodesize=legacy -O normalization=formD \
		-O xattr=sa -O devices=off -O mountpoint=none \
		-R ${MNT_DIR} ${ROOT_POOL} raidz2 $ZFS_VDEVS"
	
	run "zfs create -o mountpoint=none -p ${SYS_ROOT}/${SYS_NAME}"
	run "zfs create -o mountpoint=none    ${SYS_ROOT}/${SYS_NAME}/ROOT"
	run "zfs create -o mountpoint=/       ${SYS_ROOT}/${SYS_NAME}/ROOT/default"
	run "zfs create -o mountpoint=legacy  ${SYS_ROOT}/${SYS_NAME}/home"
	run "zfs create -o canmount=off -o mountpoint=/var     -o xattr=sa ${SYS_ROOT}/${SYS_NAME}/var"
	run "zfs create -o canmount=off -o mountpoint=/var/lib -o xattr=sa ${SYS_ROOT}/${SYS_NAME}/var/lib"
	run "zfs create -o canmount=off -o mountpoint=/var/lib/systemd -o xattr=sa ${SYS_ROOT}/${SYS_NAME}/var/lib/systemd"
	run "zfs create -o canmount=off -o mountpoint=/usr     -o xattr=sa ${SYS_ROOT}/${SYS_NAME}/usr"

}
get_disk_list
echo "${#DRV_LIST[@]} disk selected"
#echo "${DRV_LIST[*]}"
for DRV in  ${DRV_LIST[*]} ; do
	echo $DRV
done
prepare_for_start

create_file_systems
