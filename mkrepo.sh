#!/bin/sh
set -e
umask 0022
export LANG="C"


#linux=5.9.10.arch1-1 linux-lts=5.4.79-1 linux-lts=5.4.79-1

#sudo pacman -Syw --noconfirm --cachedir linux=5.9.10.arch1-1 linux-lts=5.4.79-1 ./packages/ $(cat repo_mirror_packages)
sudo pacman -Syuw  --noconfirm --ignore=linux-lts{,-headers} --cachedir ./packages/ $(cat packages.x86_64 | grep -v '#' )  | true
#rm ./packages/custom.db.tar.gz | true
repo-add ./packages/custom.db.tar.gz ./packages/* | true
