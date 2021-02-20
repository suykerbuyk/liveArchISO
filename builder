#!/bin/sh
set -e
umask 0022
export LANG="C"

sudo umount work/x86_64/airootfs/proc || true
sudo umount work/x86_64/airootfs/dev  || true
sudo umount work/x86_64/airootfs/sys  || true
if [ -d out ]; then 
	sudo rm -rf out
fi
if [ -d work ]; then 
	sudo rm -rf work
fi
if [ -d archlive ]; then 
	sudo rm -rf archlive
fi
if [ ! -d pkgcache ]; then 
	mkdir pkgcache
fi
if [ ! -d archlive ]; then 
	mkdir archlive
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
#killall darkhttpd || true

cp -r /usr/share/archiso/configs/releng/* archlive/

cp packages.x86_64 archlive/packages.x86_64
cp customize_airootfs.sh archlive/airootfs/root/
cp packages.x86_64 archlive/airootfs/root/
cp pacman.conf     archlive/pacman.conf
cp pacman.conf     archlive/airootfs/root/
cp installer.sh    archlive/airootfs/root/
cp dtest.sh        archlive/airootfs/root/
cp alez.sh         archlive/airootfs/root/
chmod +x archlive/airootfs/root/installer.sh
chmod +x archlive/airootfs/root/dtest.sh
chmod +x archlive/airootfs/root/alez.sh
cp tmux.conf       archlive/airootfs/root/.tmux.conf
YAY=$(which yay)
if [ 0 -eq $? ]; then
	cp "$YAY" archlive/airootfs/root/
	chmod 755 archlive/airootfs/root/yay
	chmod +x archlive/airootfs/root/yay
else
	echo "yay not installed on host."
fi
if [ ! -d  archlive/airootfs/opt/packages/ ] ; then
	mkdir -p archlive/airootfs/opt/packages/
fi
echo "Copying repo to install medium"
#mkdir -p archlive/airootfs/opt/
mkdir -p archlive/airootfs/var/cache/pacman/pkg
rsync -ar /var/cache/pacman/pkg/ archlive/airootfs/var/cache/pacman/pkg/
mkdir -p archlive/airootfs/etc/skel
cp tmux.conf archlive/airootfs/etc/skel/.tmux.conf
chmod +x archlive/airootfs/root/customize_airootfs.sh
#sudo chown -R johns:johns packages
sudo mkarchiso -v -w ./work -o ./out $PWD/archlive -C $PWD/pacman.conf
#sudo mkarchiso -v -w ./work -o ./out $PWD/archlive 
