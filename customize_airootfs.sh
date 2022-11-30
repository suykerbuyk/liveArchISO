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
mkdir -p /root/.ssh
mkdir -p /home/johns/.ssh

cat <<EOF_AUTHORIZED_KEYS >/root/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDx0mhoAH3g5uiHdzjrbxXUqciG4pdERrN8IqbkGBuxbTws96+T2YMNlcO0wlDqVYsZGKUH0wNaFqiFiHrBpY0CnvyzueDmfoqdn+ms2Evrdlr1bKxa1PRsq2kcC3u8mnT22UcMclrfBJwa2RvdFzlBWBjHdrlnz2AmdlU/A8vLUbVci7merzKjrq/veQhHp6JT6p8tZk1qJrxe662tefeeJ6Sb3E+F6oZRmTObdwM7i8KD9v7IWgFoHnpoSBCG51vWQ4YXRsm/bsWbJBeKtBX5nx8QW72fuftLzLpoKsCaK9HKT1blzfgsX8WNs81h90BneaviAxiiEVxcQBT6lP4n johns@dz68.suykerbuyk
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAsXkbk6ZNngBl5AyL6mAtVQkbh4wIAKYEmF7mZ/A7BjDqvbV4xuZW17/yxMtsYRKyYJce8zi3IOxPv9JKgNzkduGJKkdQngxCzCHdiXBaQrpD+SKXHU0X8Po2gd4zOs5urhxyKt0R5R6xTc2z34fg88PVxD0xo50e8Gela63B6s2MuUCRmgR8EQXnBz4G0Uspd97nkr0H6g6wq+3WKJ4evdNGc1GyAouz5AOIuMg9DlLtLsnQsGLTGXMIyBjkE61X58X7hL/B3JstpPC1ojV7O+Uz2/J29zsyWhYgz4EVV4oAmMakKak3sqjrFKYIJX+T8WVYrdZmQLY82BQXHrnirQ== jsuykerbuyk@tpasek.xyus.xyratex.com
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC6UBGYWjFRoFOUMoErPfBwwJBZG7DQex4e+pk4urG0Km8Ma4tP9lwdlLvDRipI87ziDBGcqe8LxVcHCsaYZmbS7IneL4/8xPSCtFQoF9YBDrONGLfprosIu6SB1WkxP72gVcI+zzhDOrMgz9EcQTGwiktK/Ms80/lOPtpHl9W8vgKNlZ0qGiStEHk4mZiCDmmd0O4qybLks07B4EWbcSSKXhj0p9kG445hlUi9JeOUsPy49QcWXSXxdQlxaJBnnTlOaWS0g8yTx7L7JrY8cjxnYJkqbwxdsRm3OMDsGX/yu7bQm20wUbE3UoZuGAodYA3lsVn1EQPC40dODJGEy0biYdDrTv8K3GCD6b/a9o/NOfzhAlHLqosgriu9w1c4J65EELlOpnDMF3ajlR/cuO5C0WNV8V6rzRrzZT/pvcPACq40P6acK5RY6Lo8Fg4STmVXDNQph8fOYaX/begIlavi4PgLAr9FMfOBKFHWLJzkJZolj88cvkjs/ZemJ9hZSHE= johns@archx01
EOF_AUTHORIZED_KEYS

cat <<EOF_AUTHORIZED_KEYS_USER1 >/home/johns/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDx0mhoAH3g5uiHdzjrbxXUqciG4pdERrN8IqbkGBuxbTws96+T2YMNlcO0wlDqVYsZGKUH0wNaFqiFiHrBpY0CnvyzueDmfoqdn+ms2Evrdlr1bKxa1PRsq2kcC3u8mnT22UcMclrfBJwa2RvdFzlBWBjHdrlnz2AmdlU/A8vLUbVci7merzKjrq/veQhHp6JT6p8tZk1qJrxe662tefeeJ6Sb3E+F6oZRmTObdwM7i8KD9v7IWgFoHnpoSBCG51vWQ4YXRsm/bsWbJBeKtBX5nx8QW72fuftLzLpoKsCaK9HKT1blzfgsX8WNs81h90BneaviAxiiEVxcQBT6lP4n johns@dz68.suykerbuyk
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAsXkbk6ZNngBl5AyL6mAtVQkbh4wIAKYEmF7mZ/A7BjDqvbV4xuZW17/yxMtsYRKyYJce8zi3IOxPv9JKgNzkduGJKkdQngxCzCHdiXBaQrpD+SKXHU0X8Po2gd4zOs5urhxyKt0R5R6xTc2z34fg88PVxD0xo50e8Gela63B6s2MuUCRmgR8EQXnBz4G0Uspd97nkr0H6g6wq+3WKJ4evdNGc1GyAouz5AOIuMg9DlLtLsnQsGLTGXMIyBjkE61X58X7hL/B3JstpPC1ojV7O+Uz2/J29zsyWhYgz4EVV4oAmMakKak3sqjrFKYIJX+T8WVYrdZmQLY82BQXHrnirQ== jsuykerbuyk@tpasek.xyus.xyratex.com
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC6UBGYWjFRoFOUMoErPfBwwJBZG7DQex4e+pk4urG0Km8Ma4tP9lwdlLvDRipI87ziDBGcqe8LxVcHCsaYZmbS7IneL4/8xPSCtFQoF9YBDrONGLfprosIu6SB1WkxP72gVcI+zzhDOrMgz9EcQTGwiktK/Ms80/lOPtpHl9W8vgKNlZ0qGiStEHk4mZiCDmmd0O4qybLks07B4EWbcSSKXhj0p9kG445hlUi9JeOUsPy49QcWXSXxdQlxaJBnnTlOaWS0g8yTx7L7JrY8cjxnYJkqbwxdsRm3OMDsGX/yu7bQm20wUbE3UoZuGAodYA3lsVn1EQPC40dODJGEy0biYdDrTv8K3GCD6b/a9o/NOfzhAlHLqosgriu9w1c4J65EELlOpnDMF3ajlR/cuO5C0WNV8V6rzRrzZT/pvcPACq40P6acK5RY6Lo8Fg4STmVXDNQph8fOYaX/begIlavi4PgLAr9FMfOBKFHWLJzkJZolj88cvkjs/ZemJ9hZSHE= johns@archx01
EOF_AUTHORIZED_KEYS_USER1

chmod -R 0600 /root/.ssh
chmod -R 0600 /home/johns/.ssh
chown -R johns:johns /home/johns/.ssh

# Set ssh_user password
echo "root:root"|chpasswd
echo "johns:johns"|chpasswd

# grab latest alis
#git clone https://github.com/picodotdev/alis.git /root/alis
#pacman -Sy
