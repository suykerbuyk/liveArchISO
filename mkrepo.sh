#!/bin/sh
set -e
umask 0022
export LANG="C"

TOPDIR="${PWD}"
echo $TOPDIR
#linux=5.9.10.arch1-1 linux-lts=5.4.79-1 linux-lts=5.4.79-1

#sudo pacman -Syw --noconfirm --cachedir linux=5.9.10.arch1-1 linux-lts=5.4.79-1 ./packages/ $(cat repo_mirror_packages)
echo "Fetching mainline packages"
#sudo pacman -Syuw  --noconfirm --ignore=linux-lts{,-headers} --ignore=zfs-linux-lts{,-headers} --cachedir ./packages/ $(cat packages.repo | grep -v '#' )  | true
sudo pacman -Syuw  --noconfirm --cachedir ./packages/ $(cat packages.repo | grep -v '#' )  | true
echo "Fetching zfs kernel packages"
cd archzfs-kernels && ./make.sh && cd -
echo "Copying zfs kernel packages"
rsync -v archzfs-kernels/*.zst ./packages/
#cd "${TOPDIR}"
echo "Building repo"
rm ./packages/custom.db.tar.gz | true
repo-add ./packages/custom.db.tar.gz ./packages/*
