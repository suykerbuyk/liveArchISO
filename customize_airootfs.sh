#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-3.0-or-later
exit
set -e -u
sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
locale-gen

#sed -i "s/#Server/Server/g" /etc/pacman.d/mirrorlist

# Alternatively add a root password
useradd -M -G wheel -s /usr/bin/zsh johns
chmod -R 0600 /root/.ssh
chmod -R 0600 /home/johns/.ssh
chown -R johns:johns /home/johns/.ssh

# Set ssh_user password
echo "root:root"|chpasswd
echo "johns:johns"|chpasswd

# grab latest alis
#git clone https://github.com/picodotdev/alis.git /root/alis
#pacman -Sy
