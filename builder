#!/bin/sh
#set -e
umask 0022
export LANG="C"

CACHEDIR="/opt/packages"
DB_PATH="./db"
CLEAN_START=1


PATH_OF_THIS_FILE=$(cd $(dirname "${BASH_SOURCE[0]}"); pwd)
PATH_TO_THE_DYNAMIC_DATA_DIRECTORY="${PATH_OF_THIS_FILE}/dynamic_data"
#PATH_TO_THE_OUTPUT_DIRECTORY="${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/out"
PATH_TO_THE_OUTPUT_DIRECTORY="${PATH_OF_THIS_FILE}/out"
PATH_TO_THE_PROFILE_SOURCE="/usr/share/archiso/configs/releng"
PATH_TO_PROFILE_DESTINATION="${PATH_OF_THIS_FILE}/image_profile"



sudo umount ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/x86_64/airootfs/proc || true
sudo umount ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/x86_64/airootfs/dev/pts  || true
sudo umount ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/x86_64/airootfs/dev  || true
sudo umount ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/x86_64/airootfs/sys  || true

if [ $CLEAN_START == 1 ]; then
	if [[ ! -d ${PATH_TO_THE_PROFILE_SOURCE} ]]; then
		echo ":: No archiso package installed."
		echo ":: We are going to install it now..."
		sudo pacman -Syyu --noconfirm archiso
	fi
	if [ -d ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY} ]; then 
		sudo rm -rf ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}
	fi
	mkdir ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}
	if [ -d ${PATH_TO_THE_OUTPUT_DIRECTORY} ]; then
		sudo rm -rf ${PATH_TO_THE_OUTPUT_DIRECTORY}
	fi
	mkdir ${PATH_TO_THE_OUTPUT_DIRECTORY}
	if [ -d ${PATH_TO_PROFILE_DESTINATION} ]; then 
		sudo rm -rf ${PATH_TO_PROFILE_DESTINATION}
	fi
	mkdir ${PATH_TO_PROFILE_DESTINATION}
	if [ ! -d "${CACHEDIR}" ] ; then
		sudo mkdir -p "${CACHEDIR}"
	fi
#	if [ ! -d "${PATH_TO_PROFILE_DESTINATION}/airootfs/bin" ] ; then
#		mkdir -p "${PATH_TO_PROFILE_DESTINATION}/airootfs/bin"
#	fi
	sudo rm -rf ${DB_PATH} | true
	mkdir -p ${DB_PATH}
	# Download all the needed installation packages.
	# Synchronizing local cache dir ${CACHEDIR}
	sudo pacman -Syw --noconfirm  --dbpath "${DB_PATH}"  $(cat packages.x86_64 | grep -v '#') --cachedir "${CACHEDIR}" --config ./pacman.conf
	# Clean up local package cache.
	# Make sure /etc/pacman.conf contains CleanMethod = KeepCurrent
	#sudo pacman -Sc --noconfirm
	#Make a local repository of our package cache.
	sudo rm -f "${CACHEDIR}/localcacherepo*"
	echo "Creating repo database "
	#sudo repo-add ${CACHEDIR}/localcacherepo.db.tar.gz ${CACHEDIR}/*.zst &>repo-add.log
	#sudo repo-add ${CACHEDIR}/localcacherepo.db.tar.gz ${CACHEDIR}/*.xz &>>repo-add.log
	sudo repo-add ${CACHEDIR}/localcacherepo.db.tar.gz ${CACHEDIR}/*.xz ${CACHEDIR}/*.zst &>>repo-add.log
	cp -r ${PATH_TO_THE_PROFILE_SOURCE}/* ${PATH_TO_PROFILE_DESTINATION}/
	# Enable the serial port for UEFI/Systemd boot.
	#AMEND='console=tty0 console=ttyS1,115200 text debug log.nologo'
	#for X in $(find ${PATH_TO_PROFILE_DESTINATION}/efiboot -iname '0*.conf')
	#do
	#	egrep "${AMEND}" $X >/dev/null
	#	if [[ $? == 1 ]]; then
	#		sed -i "s/^options.*/& $AMEND/" "${X}"
	#	fi
	#done
	#sed -i "s/^INITRD.*/& $AMEND/" "${PATH_TO_PROFILE_DESTINATION}/syslinux/archiso_sys-linux.cfg"
	#arch-chroot  ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/x86_64/airootfs/ systemctl enable serial-getty@ttyS0.service
fi
cp packages.x86_64 ${PATH_TO_PROFILE_DESTINATION}/packages.x86_64
cp customize_airootfs.sh ${PATH_TO_PROFILE_DESTINATION}/airootfs/root/
cp packages.x86_64 ${PATH_TO_PROFILE_DESTINATION}/airootfs/root/
cp tmux.conf       ${PATH_TO_PROFILE_DESTINATION}/airootfs/root/.tmux.conf
cp pacman.conf     ${PATH_TO_PROFILE_DESTINATION}/pacman.conf
cp pacman.conf     ${PATH_TO_PROFILE_DESTINATION}/airootfs/root/
cp installer.sh    ${PATH_TO_PROFILE_DESTINATION}/airootfs/root/
cp dtest.sh        ${PATH_TO_PROFILE_DESTINATION}/airootfs/root/
#cp alez.sh         ${PATH_TO_PROFILE_DESTINATION}/airootfs/root/
chmod +x ${PATH_TO_PROFILE_DESTINATION}/airootfs/root/installer.sh
chmod +x ${PATH_TO_PROFILE_DESTINATION}/airootfs/root/dtest.sh
#chmod +x ${PATH_TO_PROFILE_DESTINATION}/airootfs/root/alez.sh
arch-chroot ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/x86_64/airootfs/ "systemctl enable cockpit.service"
arch-chroot ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/x86_64/airootfs/ "chmod +x /root/*.sh"
YAY=$(which yay)
if [ 0 -eq $? ]; then
	cp "$YAY" ${PATH_TO_PROFILE_DESTINATION}/airootfs/bin/
	chmod 755 ${PATH_TO_PROFILE_DESTINATION}/airootfs/bin/yay
else
	echo "yay not installed on host."
fi
echo "Copying repo to install medium"
mkdir -p ${PATH_TO_PROFILE_DESTINATION}/airootfs/${CACHEDIR}
rsync -ar ${CACHEDIR}/ ${PATH_TO_PROFILE_DESTINATION}/airootfs/${CACHEDIR}
mkdir -p ${PATH_TO_PROFILE_DESTINATION}/airootfs/etc/skel
cp tmux.conf  ${PATH_TO_PROFILE_DESTINATION}/airootfs/etc/skel/.tmux.conf
chmod +x ${PATH_TO_PROFILE_DESTINATION}/airootfs/root/*.sh
#git clone https://github.com/picodotdev/alis.git/  ${PATH_TO_PROFILE_DESTINATION}/airootfs/root/alis

if [ ! -d "./alis" ] ; then
	git clone https://github.com/picodotdev/alis.git/ .
fi
rsync -avr ./alis  ${PATH_TO_PROFILE_DESTINATION}/airootfs/root/
rsync -v ./tm  ${PATH_TO_PROFILE_DESTINATION}/airootfs/bin/tm
#cat ${PATH_TO_PROFILE_DESTINATION}/profiledef.sh | grep -v 'cow_spacesize' | sed -e '$ a cow_spacesize=8G' >${PATH_TO_PROFILE_DESTINATION}/profiledef.sh
#echo "cow_spacesize=8G">>${PATH_TO_PROFILE_DESTINATION}/profiledef.sh
echo "Launching mkarchiso"
sudo mkarchiso -v -w ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY} -o ${PATH_TO_THE_OUTPUT_DIRECTORY} -C ${PATH_OF_THIS_FILE}/pacman.conf ${PATH_TO_PROFILE_DESTINATION}
#echo "Cleaning up"
#sudo rm -rf "${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}"/*
#sudo rm -rf ${DB_PATH}
