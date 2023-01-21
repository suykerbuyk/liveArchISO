#!/bin/sh
#
#mount -o remount,size=32G /run/archiso/cowspace
set -e


TGT_HOSTNAME="wrx"
ZFS_ROOT_POOL="${TGT_HOSTNAME}_zroot"
ZFS_BOOT_POOL="${TGT_HOSTNAME}_zboot"
#DEFAULT_DISK_FILTER="XS3840"
DEFAULT_DISK_FILTER="HFS960G32MED"
SYS_FS="sys"
DATA_FS="data"
SYS_ROOT="${ROOT_POOL}/${SYS_FS}"
SYS_NAME="arch"
DIR_MNT="/arch_install"
DIR_BOOT="${DIR_MNT}/boot"
DIR_ESP="${DIR_BOOT}/esp"
#TGT_TIME_ZONE="../usr/share/zoneinfo/America/Denver"
TGT_TIME_ZONE="/usr/share/zoneinfo/America/Denver"
archzfs_pgp_key="F75D9D76"

# Set a default locale during install to avoid mandb error when indexing man pages
export LANG=C

# This is required to fix grub's "failed to get canonical path" error
export ZPOOL_VDEV_NAME_PATH=1
declare -a DRV_LIST
declare -a EFI_PARTS
declare -a BOOT_PARTS
declare -a SWAP_PARTS
declare -a ROOT_PARTS

# Colors
RED='\033[0;31m'
NC='\033[0m' # No Color
DRY_RUN=0
GO_SLOW=0
LOG_FILE=dtest.log
echo "Start at $(date)" >$LOG_FILE


# Ensure we have our mount point to attach to
[[ ! -d "${DIR_MNT}" ]] && mkdir -p "${DIR_MNT}"

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
    arch-chroot "${DIR_MNT}" /bin/bash -c "${1}" &>>$LOG_FILE
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
	DISK_FILTER="${1:-$DEFAULT_DISK_FILTER}"
	
	declare -a DISK_ARRAY
	for DEV in "$(lsblk -npd -o NAME,VENDOR,MODEL,SIZE | grep -v loop)" ; do
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
		echo "DISK=$DSK"
		# To get wwn's, sort -r (reversed). 
		DEV=$( find /dev/disk/by-id -lname ../../${DSK} \
			| grep -v part | sort | head -1)
		echo "DEV=$DEV"

		DRV_LIST+=($DEV)
	done
	IFS="${OLD_IFS}"
	[ -f "${MENU_FILE}" ] && rm "${MENU_FILE}"
}
prepare_for_start() {
	msg "\nRUN: ${FUNCNAME[0]}\n"
	for MNT in $(cat /proc/mounts | grep ${DIR_MNT} | awk '{print $2}' | sort -r) ; do 
		run "umount -r ${MNT}" || true
	done
	zpool destroy ${ZFS_BOOT_POOL} || true
	zpool destroy ${ZFS_ROOT_POOL} || true
	msg "** Zapping selected disk"
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
		wait
	done
	for job in `jobs -p`; do echo "* Waiting for job: $job to complete"; wait ${job}; done
	msg "** Partitioning"
	for DRV in ${DRV_LIST[*]}
	do
		run "sgdisk -n1:1M:+1G    -t1:EF00  -c1:efi  \
		            -n2:0:+4G     -t2:BE00  -c2:boot \
		            -n3:0:-8G     -t3:BF00  -c3:root \
		            -n4:0:0       -t4:8308  -c4:swap ${DRV}" &
	done
	for job in `jobs -p`; do echo "* Waiting for job: $job to complete"; wait ${job}; done
	wait
	msg "** Partprobing disk"
	for DRV in ${DRV_LIST[*]} 
	do
		run "partprobe -s ${DRV} && udevadm trigger ${DRV}" & 
		EFI_PARTS+=("${DRV}-part1")
		BOOT_PARTS+=("${DRV}-part2")
		ROOT_PARTS+=("${DRV}-part3")
		SWAP_PARTS+=("${DRV}-part4")
       	done
	for job in `jobs -p`; do echo "* Waiting for job: $job to complete"; wait ${job}; done;
	wait
	run "udevadm trigger"
}
create_file_systems() {
	msg "\nRUN: ${FUNCNAME[0]}\n"
	partprobe -s
	udevadm trigger
	msg "** Formatting boot partitions"
	# Wait for all parts to appear.
	for PART in ${EFI_PARTS[*]} ${SWAP_PARTS[*]} ${ROOT_PARTS[*]} ${BOOT_PARTS[*]} 
	do 
		X=10
		while [ $X ] 
		do
			echo "waiting for $PART" 
			[[ -e $PART ]] && break || sleep .2 && X=$((X-1))
		done
	done
	for PART in ${EFI_PARTS[*]}; do run "mkfs.vfat $PART" & done
	for job in `jobs -p`; do echo "* Waiting for mkfs.vfat job: $job to complete"; wait ${job}; done; wait
	msg "** Formatting swap partitions"
	for PART in ${SWAP_PARTS[*]}; do run "mkswap $PART" & done
	for job in `jobs -p`; do echo "* Waiting for mkswap job: $job to complete"; wait ${job}; done; wait
	ZFS_VDEVS=""
	for PART in ${ROOT_PARTS[*]}; do ZFS_ROOT_VDEVS+="$PART "; done
	for PART in ${BOOT_PARTS[*]}; do ZFS_BOOT_VDEVS+="$PART "; done
	
	msg "** Creating ${ZFS_ROOT_POOL} pool"
	run "zpool create -f ${ZFS_BOOT_ATTRS} -R ${DIR_MNT} ${ZFS_BOOT_POOL} raidz2 $ZFS_BOOT_VDEVS"
	run "zpool create -f ${ZFS_ROOT_ATTRS} -R ${DIR_MNT} ${ZFS_ROOT_POOL} raidz2 $ZFS_ROOT_VDEVS"
	# Create container datasets
	msg "** Creating container data sets"
	run "zfs create -o canmount=off -o mountpoint=none ${ZFS_BOOT_POOL}/BOOT"
	run "zfs create -o canmount=off -o mountpoint=none ${ZFS_ROOT_POOL}/ROOT"
	run "zfs create -o canmount=off -o mountpoint=none ${ZFS_ROOT_POOL}/DATA"
	# Create root and boot file systems
	msg "** Creating root zfs file systems for 'root' and 'boot'"
	run "zfs create -o mountpoint=legacy -o canmount=noauto ${ZFS_BOOT_POOL}/BOOT/default"
	run "zfs create -o mountpoint=/      -o canmount=noauto ${ZFS_ROOT_POOL}/ROOT/default"
	msg "** mounting ${ZFS_ROOT_POOL} file system"
	run "zfs mount ${ZFS_ROOT_POOL}/ROOT/default"
	msg "** mounting ${ZFS_BOOT_POOL} file system"
	run "mkdir ${DIR_MNT}/boot"
	run "mount -t zfs ${ZFS_BOOT_POOL}/BOOT/default ${DIR_MNT}/boot"

	# Creates datasets within the root file system
	msg "** Creating system data sets"
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
	run "chmod 750  ${DIR_MNT}/root"
	run "chmod 1777 ${DIR_MNT}/var/tmp"
	msg "** Creating first efi system partition"
	run "mkdir ${DIR_MNT}/boot/esp"
	# We'll tend to the other efi parts later...	
	run "mount -t vfat ${EFI_PARTS[0]} ${DIR_ESP}"
}
generate_mounts() {
	msg "\nRUN: ${FUNCNAME[0]}\n"
# tab-separated zfs properties
# see /etc/zfs/zed.d/history_event-zfs-list-cacher.sh
export \
PROPS="name,mountpoint,canmount,atime,relatime,devices,exec\
,readonly,setuid,nbmand,encroot,keylocation\
,org.openzfs.systemd:requires,org.openzfs.systemd:requires-mounts-for\
,org.openzfs.systemd:before,org.openzfs.systemd:after\
,org.openzfs.systemd:wanted-by,org.openzfs.systemd:required-by\
,org.openzfs.systemd:nofail,org.openzfs.systemd:ignore"

	run mkdir -p ${DIR_MNT}/etc/zfs/zfs-list.cache

	zfs list -H -t filesystem -o $PROPS -r ${ZFS_ROOT_POOL} \
	> ${DIR_MNT}/etc/zfs/zfs-list.cache/${ZFS_ROOT_POOL}

	run "sed -Ei 's|${DIR_MNT}/?|/|' ${DIR_MNT}/etc/zfs/zfs-list.cache/*"

	echo ${ZFS_BOOT_POOL}/BOOT/default /boot zfs rw,xattr,posixacl 0 0 >>/${DIR_MNT}/etc/fstab
	echo UUID=$(blkid -s UUID -o value ${EFI_PARTS[0]}) /boot/esp vfat umask=0022,fmask=0022,dmask=0022 0 1 >> ${DIR_MNT}/etc/fstab
}
do_install() {
	echo "Running: do_install"
	run pacstrap -C ./local.pacman.conf ${DIR_MNT} $(cat ./packages.x86_64 | grep -v '#')
}

do_configure() {
	msg "\nRUN: ${FUNCNAME[0]}\n"
	msg "  Configuring network"
	cat <<- END_OF_NET_CONF > ${DIR_MNT}/etc/systemd/network/20-ethernet.netwok
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
	msg "** Setting hostname to $TGT_HOSTNAME"
	echo $TGT_HOSTNAME>/${DIR_MNT}/etc/hostname 
	msg "** Setting time zone to $TGT_TIME_ZONE"
	run ln -s $TGT_TIME_ZONE ${DIR_MNT}/etc/localtime
	run hwclock --systohc
	msg "** Configuring /etc/hosts"
	echo "127.0.0.1		localhost">>/${DIR_MNT}/etc/hostname 
	echo "::1		localhost">>/${DIR_MNT}/etc/hostname 
	echo "127.0.1.1		$TGT_HOSTNAME">>/${DIR_MNT}/etc/hostname 

	msg "** Configuring pacman"
	tee -a ${DIR_MNT}/etc/pacman.conf <<- 'PACMAN_CONF'
	[archzfs]
	Include = /etc/pacman.d/mirrorlist-archzfs
	PACMAN_CONF

	tee -a ${DIR_MNT}/etc/pacman.d/mirrorlist-archzfs <<- 'PACMAN_MIRRORS'
	Server = https://archzfs.com/$repo/$arch
	Server = https://mirror.sum7.eu/archlinux/archzfs/$repo/$arch
	Server = https://mirror.biocrafting.net/archlinux/archzfs/$repo/$arch
	Server = https://mirror.in.themindsmaze.com/archzfs/$repo/$arch
	PACMAN_MIRRORS

	msg "** Setting language to: $TGT_LANGUAGE"
	run "sed -i 's/#en_US.UTF-8/en_US.UTF-8/g' ${DIR_MNT}/etc/locale.gen"
	echo "LANG=en_US.UTF-8" >> ${DIR_MNT}/etc/locale.conf
	#arch-chroot /mnt locale-gen
	chrun "locale-gen"

	msg "** Configuring mkinitcpio"
	run mv ${DIR_MNT}/etc/mkinitcpio.conf ${DIR_MNT}/etc/mkinitcpio.conf.original
	tee ${DIR_MNT}/etc/mkinitcpio.conf <<-MKINIT_EOF
	HOOKS=(base udev autodetect modconf block keyboard zfs filesystems)
	MKINIT_EOF
	msg "** Configuring systemd update hook"
	run "mkdir -p ${DIR_MNT}/etc/pacman.d/hooks"
	tee ${DIR_MNT}/etc/pacman.d/hooks/100-systemd-boot.hook <<-MKSYSD_HOOK
	[Trigger]
	Type = Package
	Operation = Upgrade
	Target = systemd

	[Action]
	Description = update systemd-boot
	When = PostTransaction
	Exec = /usr/bin/bootctl update
	MKSYSD_HOOK
	# Enable root ssh
	msg "** enabling root ssh"
	run "sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' ${DIR_MNT}/etc/ssh/sshd_config"
	#zgenhostid -f -o ${DIR_MNT}/etc/hostid
	run systemd-machine-id-setup --root=${DIR_MNT}
	chrun "pacman-key -r DDF7DB817396A49B2A2723F7403BD972F75D9D76"
	chrun "pacman-key  --lsign DDF7DB817396A49B2A2723F7403BD972F75D9D76"
	run "bootctl --path=${DIR_ESP} install"
	run "mkdir -p $DIR_ESP/loader/entries/"
	chrun "zpool set cachefile=/etc/zfs/zpool.cache ${ZFS_ROOT_POOL}"
	chrun "zpool set cachefile=/etc/zfs/zpool.cache ${ZFS_BOOT_POOL}"
	run "systemctl enable  --root=${DIR_MNT} \
		cockpit.service \
		sshd.service \
		systemd-timesyncd \
		zfs-import-cache.service \
		zfs-import.target \
		zfs-mount.service \
		zfs.target"
	chrun "mkinitcpio -P"
	echo "Working on: ${DIR_ESP}/loader/loader.conf"
	tee "${DIR_ESP}/loader/loader.conf" <<-LOADER_CONF
	timeout 5
	default archlinux.conf
	editor 0
	LOADER_CONF
	msg "** Configuring arch boot config"
	tee ${DIR_MNT}/boot/esp/loader/entries/archlinux.conf <<-ARCHLINUX_CONF
	title           Arch Linux
	linux           vmlinuz-linux
	initrd          amd-ucode.img
	initrd          intel-ucode.img
	initrd          initramfs-linux.img
	options         zfs=$ZFS_ROOT_POOL/ROOT/default rw
	ARCHLINUX_CONF
#	umount -R ${DIR_MNT}
#	zpool export -a
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
#ls -lah /dev/disk/by-id/wwn-0x5000c500* | grep part | awk -F '/' '{print $5 "  " $7}' | sed 's/ -> .. //g'  |  while read a; do WWN=$(echo $a | awk -F ' ' '{print $1}'); DEV=$(echo $a | awk -F ' ' '{print $2}'); ln -s /dev/$DEV /dev/$WWN; done

echo "Stop at $(date)" >>$LOG_FILE

#pacman-key -r DDF7DB817396A49B2A2723F7403BD972F75D9D76
# pacman-key --lsign DDF7DB817396A49B2A2723F7403BD972F75D9D76
