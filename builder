#!/bin/sh
set -e
umask 0022
export LANG="C"

CACHEDIR=/opt/packages

CLEAN_START=1

sudo umount work/x86_64/airootfs/proc || true
sudo umount work/x86_64/airootfs/dev  || true
sudo umount work/x86_64/airootfs/sys  || true

if [ $CLEAN_START == 1 ]; then

	if [ -d out ]; then 
		sudo rm -rf out
	fi
	if [ -d work ]; then 
		sudo rm -rf work
	fi
	if [ -d img_profile ]; then 
		sudo rm -rf img_profile
	fi
	if [ ! -d img_profile ]; then 
		mkdir img_profile
	fi
	if [ ! -d "${CACHEDIR}" ] ; then
		sudo mkdir "${CACHEDIR}"
	fi
	# Make sure we have archiso installed for mkachiso tool.
	if [ ! -d /usr/share/archiso/configs/releng/ ]; then
		sudo pacman -Sy archiso
	fi
	sudo rm -rf ./db | true
	mkdir ./db
	# Download all the needed installation packages.
	# Synchronizing local cache dir ${CACHEDIR}
	sudo pacman -Syw --dbpath ./db --noconfirm  $(cat packages.x86_64 | grep -v '#') --cachedir "${CACHEDIR}"
	# Clean up local package cache.
	# Make sure /etc/pacman.conf contains CleanMethod = KeepCurrent
	#sudo pacman -Sc --noconfirm
	#Make a local repository of our package cache.
	sudo rm -f "${CACHEDIR}"/localcacherepo*
	echo "Creating repo database "
	sudo repo-add ${CACHEDIR}/localcacherepo.db.tar.gz ${CACHEDIR}/* &>repo-add.log
	cp -r /usr/share/archiso/configs/releng/* ./img_profile/
fi
#rsync -ar ./releng_profile/ ./img_profile/ --delete
rsync -ar ./releng_profile/ ./img_profile/
cp packages.x86_64 img_profile/packages.x86_64
cp customize_airootfs.sh img_profile/airootfs/root/
cp packages.x86_64 img_profile/airootfs/root/
cp tmux.conf       img_profile/airootfs/root/.tmux.conf
cp pacman.conf     img_profile/pacman.conf
cp pacman.conf     img_profile/airootfs/root/
cp installer.sh    img_profile/airootfs/root/
cp dtest.sh        img_profile/airootfs/root/
cp alez.sh         img_profile/airootfs/root/
chmod +x img_profile/airootfs/root/installer.sh
chmod +x img_profile/airootfs/root/dtest.sh
chmod +x img_profile/airootfs/root/alez.sh
YAY=$(which yay)
if [ 0 -eq $? ]; then
	cp "$YAY" img_profile/airootfs/root/
	chmod 755 img_profile/airootfs/root/yay
	chmod +x img_profile/airootfs/root/yay
else
	echo "yay not installed on host."
fi
echo "Copying repo to install medium"
mkdir -p img_profile/airootfs/opt/packages
rsync -ar ${CACHEDIR} img_profile/airootfs/opt/packages/
mkdir -p img_profile/airootfs/etc/skel
cp tmux.conf  img_profile/airootfs/etc/skel/.tmux.conf
chmod +x img_profile/airootfs/root/*.sh
sudo mkarchiso -v -w ./work -o ./out -C $PWD/pacman.conf $PWD/img_profile
#sudo mkarchiso -v -w ./work -o ./out $PWD/img_profile
