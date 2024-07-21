#!/bin/sh
set -e
umask 0022
export LANG="C"

CACHEDIR="/opt/packages"
DB_PATH="./db"
CLEAN_START=1


PATH_OF_THIS_FILE=$(cd $(dirname "${BASH_SOURCE[0]}"); pwd)
PATH_OF_OUTPUT_ISO="${PATH_OF_THIS_FILE}/out"

PATH_OF_PROFILE_SRC="/usr/share/archiso/configs/releng"
PATH_OF_PROFILE_TGT="${PATH_OF_THIS_FILE}/image_profile"
PATH_OF_SOURCE_FS="${PATH_OF_PROFILE_SRC}/airootfs"
PATH_OF_TARGET_FS="${PATH_OF_THIS_FILE}/dynamic_data/x84_64/airootfs"


umount_previous() {
	sudo umount ${PATH_OF_TARGET_FS}/proc || true
	sudo umount ${PATH_OF_TARGET_FS}/dev/pts  || true
	sudo umount ${PATH_OF_TARGET_FS}/dev  || true
	sudo umount ${PATH_OF_TARGET_FS}/sys  || true
	sudo rm -rf "${PATH_OF_TARGET_FS}"
}

#Creates subdirectory in the air root fs tree.
make_air_root_dir() {
	TARGET="${PATH_OF_TARGET_FS}/$1"
	if [ ! -d "${TARGET}" ]
	then
		echo "Ensuring $1 exists in target file system: $TARGET"
		mkdir -p "${TARGET}"
	else
		echo "Reusing target path ${1}"
	fi
}

get_air_root_dir() {
	echo "${PATH_OF_TARGET_FS}/$1"
}

enable_serial_port_console() {
	set +e
	echo "Enabling the serial port for UEFI/Systemd boot."
	AMEND='console=tty0 console=ttyS0,115200 text debug log.nologo'
	for X in $(find ${PATH_OF_TARGET_FS}/efiboot/loader/entries/ -iname '*.conf')
	do
		echo "Working on $X"
		grep -E "${AMEND}" $X >/dev/null
		if [[ $? == 1 ]]; then
			sed -i "s/^options.*/& $AMEND/" "${X}"
		fi
	done
	set -e
	sed -i "s/^INITRD.*/& $AMEND/" "${PATH_OF_TARGET_FS}/syslinux/archiso_sys-linux.cfg"
}

configure_users(){
	mkdir -p   ${PATH_OF_PROFILE_TGT}/airootfs/etc/
	echo "Configuring Users"
cat <<- 'GROUP_EOF' >${PATH_OF_PROFILE_TGT}/airootfs/etc/group
root:x:0:root
johns:x:1000:

GROUP_EOF

cat <<- 'PASSWD_EOF' >${PATH_OF_PROFILE_TGT}/airootfs/etc/passwd
root:x:0:0:root:/root:/usr/bin/zsh
johns:x:1000:1000::/home/johns:/usr/bin/zsh

PASSWD_EOF

cat <<- 'SHADOW_EOF' >${PATH_OF_PROFILE_TGT}/airootfs/etc/shadow
root:$y$j9T$0WZgZqVoCJW.7pyNlcM/60$0LvXcFObvf2DeZwqZh8WkHbmKYx.n.2NdixLA/RjKY9:19897::::::
johns:$y$j9T$o4fRRMqBsrcs1NNYjvfqz0$7.S3umMeRlSaQrJ43FyaJjqQ9f9V0GSaMWDWI8x9qD1:19897:0:99999:7:::

SHADOW_EOF

cat <<- 'GSHADOW_EOF' >${PATH_OF_PROFILE_TGT}/airootfs/etc/gshadow
root:::root
wheel:!*::johns
johns:!::

GSHADOW_EOF

mkdir -p      ${PATH_OF_PROFILE_TGT}/airootfs/root/.ssh
mkdir -p      ${PATH_OF_PROFILE_TGT}/airootfs/home/johns/.ssh
cat <<- EOF_AUTHORIZED_KEYS >${PATH_OF_PROFILE_TGT}/airootfs/root/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC6UBGYWjFRoFOUMoErPfBwwJBZG7DQex4e+pk4urG0Km8Ma4tP9lwdlLvDRipI87ziDBGcqe8LxVcHCsaYZmbS7IneL4/8xPSCtFQoF9YBDrONGLfprosIu6SB1WkxP72gVcI+zzhDOrMgz9EcQTGwiktK/Ms80/lOPtpHl9W8vgKNlZ0qGiStEHk4mZiCDmmd0O4qybLks07B4EWbcSSKXhj0p9kG445hlUi9JeOUsPy49QcWXSXxdQlxaJBnnTlOaWS0g8yTx7L7JrY8cjxnYJkqbwxdsRm3OMDsGX/yu7bQm20wUbE3UoZuGAodYA3lsVn1EQPC40dODJGEy0biYdDrTv8K3GCD6b/a9o/NOfzhAlHLqosgriu9w1c4J65EELlOpnDMF3ajlR/cuO5C0WNV8V6rzRrzZT/pvcPACq40P6acK5RY6Lo8Fg4STmVXDNQph8fOYaX/begIlavi4PgLAr9FMfOBKFHWLJzkJZolj88cvkjs/ZemJ9hZSHE= johns@archx01
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILkEeb/ItdBGrLJVoz/AYk/1sC4V9GwvqvzoA1Ch5hoC um690
EOF_AUTHORIZED_KEYS

cat <<- EOF_AUTHORIZED_KEYS_USER1 >${PATH_OF_PROFILE_TGT}/airootfs/home/johns/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC6UBGYWjFRoFOUMoErPfBwwJBZG7DQex4e+pk4urG0Km8Ma4tP9lwdlLvDRipI87ziDBGcqe8LxVcHCsaYZmbS7IneL4/8xPSCtFQoF9YBDrONGLfprosIu6SB1WkxP72gVcI+zzhDOrMgz9EcQTGwiktK/Ms80/lOPtpHl9W8vgKNlZ0qGiStEHk4mZiCDmmd0O4qybLks07B4EWbcSSKXhj0p9kG445hlUi9JeOUsPy49QcWXSXxdQlxaJBnnTlOaWS0g8yTx7L7JrY8cjxnYJkqbwxdsRm3OMDsGX/yu7bQm20wUbE3UoZuGAodYA3lsVn1EQPC40dODJGEy0biYdDrTv8K3GCD6b/a9o/NOfzhAlHLqosgriu9w1c4J65EELlOpnDMF3ajlR/cuO5C0WNV8V6rzRrzZT/pvcPACq40P6acK5RY6Lo8Fg4STmVXDNQph8fOYaX/begIlavi4PgLAr9FMfOBKFHWLJzkJZolj88cvkjs/ZemJ9hZSHE= johns@archx01
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILkEeb/ItdBGrLJVoz/AYk/1sC4V9GwvqvzoA1Ch5hoC um690
EOF_AUTHORIZED_KEYS_USER1
}

build_repo_mirror() {
	sudo rm -rf ${DB_PATH} | true
	mkdir -p ${DB_PATH}
	# Download all the needed installation packages.
	# Synchronizing local cache dir ${CACHEDIR}
	sudo pacman -Syw --noconfirm  --dbpath "${DB_PATH}" \
		$(cat packages.x86_64 | grep -v '#') --cachedir "${CACHEDIR}" --config ./pacman.conf
	# Clean up local package cache.
	# Make sure /etc/pacman.conf contains CleanMethod = KeepCurrent
	#sudo pacman -Sc --noconfirm
	#Make a local repository of our package cache.
	sudo rm -f "${CACHEDIR}/localcacherepo*"
	echo "Creating repo database "
	sudo repo-add ${CACHEDIR}/localcacherepo.db.tar.gz ${CACHEDIR}/*.xz ${CACHEDIR}/*.zst &>>repo-add.log  || true
}
configure_profile() {
	if [[ ! -d ${PATH_OF_PROFILE_SRC} ]]; then
		echo ":: No archiso package installed."
		echo ":: We are going to install it now..."
		sudo pacman -Syyu --noconfirm archiso
	else
		echo "Using installed archiso packages."
	fi
	if [ -d ${PATH_OF_PROFILE_TGT} ]; then 
		echo "Clearing ${PATH_OF_PROFILE_TGT}"
		sudo rm -rf ${PATH_OF_PROFILE_TGT}
	else
		echo "Does Not Exists: ${PATH_OF_PROFILE_TGT}"
	fi
	mkdir ${PATH_OF_PROFILE_TGT}
	if [ -d ${PATH_OF_OUTPUT_ISO} ]; then
		sudo rm -rf ${PATH_OF_OUTPUT_ISO}
	fi
	mkdir ${PATH_OF_OUTPUT_ISO}
	if [ -d ${PATH_OF_PROFILE_TGT} ]; then 
		sudo rm -rf ${PATH_OF_PROFILE_TGT}
	fi
	mkdir ${PATH_OF_PROFILE_TGT}
	if [ ! -d "${CACHEDIR}" ] ; then
		sudo mkdir -p "${CACHEDIR}"
	fi
	#start with the upstream releng config
	cp -r ${PATH_OF_PROFILE_SRC}/* ${PATH_OF_PROFILE_TGT}/

	#mkdir -p          "${PATH_OF_PROFILE_TGT}/airootfs/bin"
	mkdir -p          "${PATH_OF_PROFILE_TGT}/airootfs/etc"
	mkdir -p          "${PATH_OF_PROFILE_TGT}/airootfs/etc/systemd/system/getty@tty1.service.d"
	mkdir -p          "${PATH_OF_PROFILE_TGT}/airootfs/etc/systemd/system/getty@ttyS0.service.d"
	mkdir -p          "${PATH_OF_PROFILE_TGT}/airootfs/etc/systemd/system/getty.target.wants"
	mkdir -p          "${PATH_OF_PROFILE_TGT}/airootfs/etc/systemd/system/sockets.target.wants"
	sudo ln -s /usr/lib/systemd/system/serial-getty@.service \
		${PATH_OF_PROFILE_TGT}/airootfs/etc/systemd/system/getty.target.wants/serial-getty@ttyS0.service
	sudo ln -s /usr/lib/systemd/system/cockpit.socket \
		${PATH_OF_PROFILE_TGT}/airootfs/etc/systemd/system/sockets.target.wants/cockpit.socket
	#sudo rsync -avr ${PATH_OF_TARGET_FS}/etc/systemd/system/getty@tty1.service.d/ \
	#	   ${PATH_OF_TARGET_FS}/etc/systemd/system/getty@ttyS0.service.d/
}

copy_files() {
	echo "Copying files into profile directory"
	mkdir -p                  ${PATH_OF_PROFILE_TGT}/airootfs/etc/
	mkdir -p                  ${PATH_OF_PROFILE_TGT}/airootfs/root/
	#mkdir -p                  ${PATH_OF_PROFILE_TGT}/airootfs/bin/
	mkdir -p                  ${PATH_OF_PROFILE_TGT}/airootfs/etc/skel/
	cp packages.x86_64        ${PATH_OF_PROFILE_TGT}/packages.x86_64
	cp pacman.conf            ${PATH_OF_PROFILE_TGT}/pacman.conf
	#cp customize_airootfs.sh  ${PATH_OF_PROFILE_TGT}/airootfs/root/
	cp packages.x86_64        ${PATH_OF_PROFILE_TGT}/airootfs/root/
	cp tmux.conf              ${PATH_OF_PROFILE_TGT}/airootfs/root/.tmux.conf
	cp pacman.conf            ${PATH_OF_PROFILE_TGT}/airootfs/root/
	cp installer.sh           ${PATH_OF_PROFILE_TGT}/airootfs/root/
	cp dtest*.sh              ${PATH_OF_PROFILE_TGT}/airootfs/root/
	YAY=$(which yay)
	#if [ 0 -eq $? ]; then
	#	cp "$YAY" ${PATH_OF_PROFILE_TGT}/airootfs/bin/
	#	chmod 755 ${PATH_OF_PROFILE_TGT}/airootfs/bin/yay
	#else
	#	echo "yay not installed on host."
	#fi

	echo "Copying repo to install medium"
	mkdir -p ${PATH_TO_AIR_ROOT_FS}/${CACHEDIR}
	echo "rsync -arv ${CACHEDIR}/ ${PATH_TO_AIR_ROOT_FS}/${CACHEDIR}"
	rsync -arv ${CACHEDIR}/ ${PATH_TO_AIR_ROOT_FS}/${CACHEDIR}
	mkdir -p ${PATH_TO_AIR_ROOT_FS}/etc/skel
	cp tmux.conf  ${PATH_OF_PROFILE_TGT}/airootfs/etc/skel/.tmux.conf
	#cp switch*.txz ${PATH_OF_PROFILE_TGT}/airootfs/root/
	#cp switch_boot_bios.img ${PATH_OF_PROFILE_TGT}/airootfs/root/
	#git clone https://github.com/picodotdev/alis.git/  ${PATH_OF_PROFILE_TGT}/airootfs/root/alis

	if [ ! -d "./alis" ] ; then
		git clone https://github.com/picodotdev/alis.git/ ./alis
	fi
	rsync -avr ${PATH_OF_THIS_FILE}/alis/  ${PATH_OF_PROFILE_TGT}/airootfs/root/alis/
	#rsync -v ${PATH_OF_THIS_FILE}/tm  ${PATH_OF_PROFILE_TGT}/airootfs/bin/tm
}

make_iso() {
	echo "Launching mkarchiso"
	echo "mkarchiso -v -w dynamic_data -o ${PATH_OF_OUTPUT_ISO} -C ${PATH_OF_PROFILE_TGT}/pacman.conf ${PATH_OF_PROFILE_TGT}"
	sudo mkarchiso -v -w dynamic_data \
		-o ${PATH_OF_OUTPUT_ISO} \
		-C ${PATH_OF_PROFILE_TGT}/pacman.conf \
		   ${PATH_OF_PROFILE_TGT}
}
umount_previous
configure_profile
build_repo_mirror
copy_files
#enable_serial_port_console
configure_users
make_iso

echo -n "Completed at "
date

#echo "Cleaning up"
#sudo rm -rf "${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}"/*
#sudo rm -rf ${DB_PATH}
#  ["arch.zfs.on.root.sh"]="0:0:755"
#  ["dtest2.sh"]="0:0:755"
#  ["dtest3.sh"]="0:0:755"
#  ["dtest.sh"]="0:0:755"
#  ["installer.sh"]="0:0:755"
