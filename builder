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
mkdir archlive
cp -r /usr/share/archiso/configs/releng/* archlive/


cp packages.x86_64 archlive/packages.x86_64
cp pacman.conf archlive/pacman.conf
cp customize_airootfs.sh archlive/airootfs/root/
cp installer.sh archlive/airootfs/root/
cp tmux.conf archlive/airootfs/root/.tmux.conf
cp tmux.conf archlive/airootfs/etc/skel/.tmux.conf
chmod +x archlive/airootfs/root/customize_airootfs.sh
#sudo chown -R johns:johns packages
#sudo mkarchiso -v -w ./work -o ./out $PWD/archlive -C $PWD/pacman.conf
sudo mkarchiso -v -w ./work -o ./out $PWD/archlive 
