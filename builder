#!/bin/sh
set -e
umask 0022
export LANG="C"
#sudo pacman -Syw --noconfirm --cachedir ./packages/ $(cat packages.repo)
#sudo repo-add -R ./packages/custom.db.tar.gz ./packages/* || true
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


# tee -a archlive/pacman.conf << EOF_PAC_CONF
# [multilib]
# Include = /etc/pacman.d/mirrorlist

#[archzfs]
#Server = http://archzfs.com/$repo/$arch
# EOF_PAC_CONF

tee -a archlive/airootfs/etc/passwd << EOF_USERS
johns:x:1000:1000::/home/johns:/usr/bin/zsh
EOF_USERS


tee -a archlive/airootfs/etc/shadow << EOF_PASSWDS
root:$6$W7MwbxQr$FwEJHFRcj23SCpyiBPCO67YvxfP0EF515ieaOWOo/GI2qFIfvrkzUlZhsIHmQfsO1TJSylZ2Ipf1wAeDU4hyj0:16889::::::
johns:$6$6nUryIcc1paH4iPn$ZwgtEz2WsuBgGFt.huWf9W05SkA2/WNTBtJ.Zn2l.Bj0ps2TYWa0kfuaptWLUfdrEwSlEW7Fs4NLzluY6kpSA1:18571:0:99999:7:::
EOF_PASSWDS


tee -a archlive/airootfs/etc/gshadow << EOF_GROUPS
root:x:0:root
wheel:x:10:root,johns
users:x:100:johns
johns:x:1000:
EOF_GROUPS

cp packages.iso archlive/packages.x86_64
cp pacman.conf archlive/pacman.conf
sudo chown -R johns:johns packages
sudo mkarchiso -v -w ./work -o ./out $PWD/archlive -C $PWD/pacman.conf
