#!/bin/sh
set -e
umask 0022
export LANG="C"

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

	# Make sure we have archiso installed for mkachiso tool.
	if [ ! -d /usr/share/archiso/configs/releng/ ]; then
		sudo pacman -Sy archiso
	fi
	# Download all the needed installation packages.
	sudo pacman -Syw --noconfirm  $(cat packages.x86_64 | grep -v '#')
	# Clean up local package cache.
	# Make sure /etc/pacman.conf contains CleanMethod = KeepCurrent
	sudo pacman -Sc --noconfirm
	#Make a local repository of our package cache.
	sudo rm -f /var/cache/pacman/pkg/localcacherepo*
	sudo repo-add /var/cache/pacman/pkg/localcacherepo.db.tar.gz /var/cache/pacman/pkg/*
	cp -r /usr/share/archiso/configs/releng/* ./img_profile/
fi
rsync -avr ./releng_profile/ ./img_profile/ --delete
cp packages.x86_64 img_profile/packages.x86_64
cp customize_airootfs.sh img_profile/airootfs/root/
cp packages.x86_64 img_profile/airootfs/root/
cp pacman.conf     img_profile/pacman.conf
cp pacman.conf     img_profile/airootfs/root/
cp installer.sh    img_profile/airootfs/root/
cp dtest.sh        img_profile/airootfs/root/
cp alez.sh         img_profile/airootfs/root/
chmod +x img_profile/airootfs/root/installer.sh
chmod +x img_profile/airootfs/root/dtest.sh
chmod +x img_profile/airootfs/root/alez.sh
cp tmux.conf       img_profile/airootfs/root/.tmux.conf
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
rsync -ar /var/cache/pacman/pkg/ img_profile/airootfs/opt/packages/
mkdir -p img_profile/airootfs/etc/skel
cp tmux.conf img_profile/airootfs/etc/skel/.tmux.conf
chmod +x img_profile/airootfs/root/*.sh
#sudo mkarchiso $PWD/releng_profile -v -w ./work -o ./out $PWD/img_profile -C $PWD/pacman.conf
sudo mkarchiso -v -w ./work -o ./out $PWD/img_profile -C $PWD/pacman.conf
