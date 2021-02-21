#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

set -e -u

# Warning: customize_airootfs.sh is deprecated! Support for it will be removed in a future archiso version.

sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
locale-gen

#sed -i "s/#Server/Server/g" /etc/pacman.d/mirrorlist

# Alternatively add a root password
useradd -M -G wheel -s /usr/bin/zsh johns
mkdir /root/.ssh
mkdir -p /home/johns/.ssh

cat <<EOF_AUTHORIZED_KEYS >/root/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDx0mhoAH3g5uiHdzjrbxXUqciG4pdERrN8IqbkGBuxbTws96+T2YMNlcO0wlDqVYsZGKUH0wNaFqiFiHrBpY0CnvyzueDmfoqdn+ms2Evrdlr1bKxa1PRsq2kcC3u8mnT22UcMclrfBJwa2RvdFzlBWBjHdrlnz2AmdlU/A8vLUbVci7merzKjrq/veQhHp6JT6p8tZk1qJrxe662tefeeJ6Sb3E+F6oZRmTObdwM7i8KD9v7IWgFoHnpoSBCG51vWQ4YXRsm/bsWbJBeKtBX5nx8QW72fuftLzLpoKsCaK9HKT1blzfgsX8WNs81h90BneaviAxiiEVxcQBT6lP4n johns@dz68.suykerbuyk
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAsXkbk6ZNngBl5AyL6mAtVQkbh4wIAKYEmF7mZ/A7BjDqvbV4xuZW17/yxMtsYRKyYJce8zi3IOxPv9JKgNzkduGJKkdQngxCzCHdiXBaQrpD+SKXHU0X8Po2gd4zOs5urhxyKt0R5R6xTc2z34fg88PVxD0xo50e8Gela63B6s2MuUCRmgR8EQXnBz4G0Uspd97nkr0H6g6wq+3WKJ4evdNGc1GyAouz5AOIuMg9DlLtLsnQsGLTGXMIyBjkE61X58X7hL/B3JstpPC1ojV7O+Uz2/J29zsyWhYgz4EVV4oAmMakKak3sqjrFKYIJX+T8WVYrdZmQLY82BQXHrnirQ== jsuykerbuyk@tpasek.xyus.xyratex.com
EOF_AUTHORIZED_KEYS

cat <<EOF_AUTHORIZED_KEYS_USER1 >/home/johns/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDx0mhoAH3g5uiHdzjrbxXUqciG4pdERrN8IqbkGBuxbTws96+T2YMNlcO0wlDqVYsZGKUH0wNaFqiFiHrBpY0CnvyzueDmfoqdn+ms2Evrdlr1bKxa1PRsq2kcC3u8mnT22UcMclrfBJwa2RvdFzlBWBjHdrlnz2AmdlU/A8vLUbVci7merzKjrq/veQhHp6JT6p8tZk1qJrxe662tefeeJ6Sb3E+F6oZRmTObdwM7i8KD9v7IWgFoHnpoSBCG51vWQ4YXRsm/bsWbJBeKtBX5nx8QW72fuftLzLpoKsCaK9HKT1blzfgsX8WNs81h90BneaviAxiiEVxcQBT6lP4n johns@dz68.suykerbuyk
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAsXkbk6ZNngBl5AyL6mAtVQkbh4wIAKYEmF7mZ/A7BjDqvbV4xuZW17/yxMtsYRKyYJce8zi3IOxPv9JKgNzkduGJKkdQngxCzCHdiXBaQrpD+SKXHU0X8Po2gd4zOs5urhxyKt0R5R6xTc2z34fg88PVxD0xo50e8Gela63B6s2MuUCRmgR8EQXnBz4G0Uspd97nkr0H6g6wq+3WKJ4evdNGc1GyAouz5AOIuMg9DlLtLsnQsGLTGXMIyBjkE61X58X7hL/B3JstpPC1ojV7O+Uz2/J29zsyWhYgz4EVV4oAmMakKak3sqjrFKYIJX+T8WVYrdZmQLY82BQXHrnirQ== jsuykerbuyk@tpasek.xyus.xyratex.com
EOF_AUTHORIZED_KEYS_USER1

chmod -R 0600 /root/.ssh
chmod -R 0600 /home/johns/.ssh
chown -R johns:johns /home/johns/.ssh

# Set ssh_user password
echo "root:root"|chpasswd
echo "johns:johns"|chpasswd

# Enable ssh
systemctl enable sshd.service
#pacman -Sy
