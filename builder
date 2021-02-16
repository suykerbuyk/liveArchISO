#!/bin/sh
set -e
umask 0022
export LANG="C"
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
cp -r /usr/share/archiso/configs/releng/* archlive/
#sudo pacman -Syw  --noconfirm --config pacman.conf --cachedir ./pkgcache $(cat packages.x86_64 | grep -v '#')

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
rsync -ar pkgcache/ archlive/airootfs/opt/packages/
rsync -ar /var/cache/pacman/pkg/ archlive/airootfs/opt/packages/
mkdir -p archlive/airootfs/etc/skel
cp tmux.conf archlive/airootfs/etc/skel/.tmux.conf
chmod +x archlive/airootfs/root/customize_airootfs.sh
#sudo chown -R johns:johns packages
sudo mkarchiso -v -w ./work -o ./out $PWD/archlive -C $PWD/pacman.conf
#sudo mkarchiso -v -w ./work -o ./out $PWD/archlive 
