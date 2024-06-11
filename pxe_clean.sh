#!/bin/bash
#wget / curl kan vervangen worden door axel (zit gewoon in de repo) - usage: axel -n 1 -o LokaleNaam.iso http://website/download
#deze versie van het script streeft naar zo min mogelijk tekens gebruiken
#DEBIAN PXE NETWORK BOOT 1eNIC: NAT 2eNIC: intern netwerk- pxelinux voor lpxelinux.0 voor http boot, alles als root uitvoeren:
apt install dnsmasq wget apt-cacher-ng -y

printf '\nauto enp0s8 \niface enp0s8 inet static\naddress 10.1.1.1/8' >> /etc/network/interfaces
#ifup enp0s8 #reboot aan het einde brengt deze interface ook weer up

mkdir /ftpd/pxelinux.cfg -p

printf 'interface=enp0s8\ndhcp-range=10.1.1.2,10.1.1.99,255.0.0.0,9h\nenable-tftp\ntftp-root=/ftpd\ndhcp-boot=pxelinux.0\nsynth-domain=test.lan,10.1.1.2,10.1.1.99\ndhcp-authoritative' > /etc/dnsmasq.conf
/etc/init.d/dnsmasq restart

wget -P /tmp http://ftp.debian.org/debian/dists/bookworm/main/installer-amd64/current/images/netboot/netboot.tar.gz
cd /tmp && tar -xzvf netboot.tar.gz
#alles op 1 plaats plaatsen ipv subdirs en symlinks #menu.32 / ldlinux.c32 / libutil.c32 kopieren naar /ftpd

cp /tmp/debian-installer/amd64/* /tmp/debian-installer/amd64/boot-screens/* /ftpd

printf 'default vesamenu.c32\nlabel Debian12\nkernel linux initrd=initrd.gz vga=788 url=tftp://10.1.1.1/preseed.cfg ipv6.disable=1 language=nl country=NL keymap=us' > /ftpd/pxelinux.cfg/default

printf 'd-i debian-installer/locale string en_US.UTF-8\nd-i debian-installer/language string en\nd-i debian-installer/country string NL\nd-i mirror/http/proxy string http://10.1.1.1:3142\nd-i mirror/http/hostname string deb.debian.org' > /ftpd/preseed.cfg

apt remove wget -y
reboot
---------------------------------------------------------------------------------------------------------------------
#GPARTED LIVE werkt 21-04-2024!
apt install nginx wget unzip -y
wget -P /tmp https://netcologne.dl.sourceforge.net/project/gparted/gparted-live-stable/1.6.0-3/gparted-live-1.6.0-3-i686.zip
cd /tmp && unzip gparted*.zip
cp /tmp/live/{vmlinuz,initrd.img,filesystem.squashfs} /var/www/html
printf '\nlabel Gparted Live\nMENU LABEL GParted Live\nkernel http://10.1.1.1/vmlinuz initrd=http://10.1.1.1/initrd.img boot=live config components union=overlay username=user noswap noeject vga=788 fetch=http://10.1.1.1/filesystem.squashfs\n' >> /ftpd/pxelinux.cfg/default
apt remove wget unzip -y
---------------------------------------------------------------------------------------------------------------------

tar cvf "$(date '+%Y-%m-%d')-DebianPXEserver.tar" /var/tfpd /etc/dnsmasq.conf /etc/network/interfaces backup.sh

# mv /tmp/debian-installer/amd64/linux /ftpd/ #mv /tmp/debian-installer/amd64/initrd.gz /ftpd/ #mv /tmp/debian-installer/amd64/boot-screens/ldlinux.c32 /ftpd/ #mv /tmp/debian-installer/amd64/boot-screens/vesamenu.c32 /ftpd/ #mv /tmp/debian-installer/amd64/boot-screens/libutil.c32 /ftpd/ #mv /tmp/debian-installer/amd64/boot-screens/libcom32.c32 /ftpd/
# uitwerken ipv vesamenu: cp /usr/lib/syslinux/modules/bios/menu.c32 /ftpd/ && cp /usr/lib/syslinux/modules/bios/ldlinux.c32 /ftpd
# zonder menu/ vesamenu kan ook - als je in /ftpd/pxelinux.cfg/default DEFAULT 'label' instelt daaronder moet het label wel bestaan..
# cd !$ #verander directory naar laatst aangemaakte / genoemde folder
# nano /etc/apt-cacher-ng/acng.conf #	BindAddress: 10.1.1.1
# apt install pxelinux - menu.c32 gekopieerd (text only) heeft nodig: ldlinux.c32 / libutil.c32)
# 1.1.1.1 niet gebruiken - vanaf 10.x.x.x is voor intern gebruik
# kladt: deb.debian.org
# proberen minimal installatie te maken (er is een parameter om recommends NIET te installeren
# https://wiki.debian.org/PXEBootInstall nog eens lezen
# https://www.debian.org/releases/bookworm/example-preseed.txt
# WAT? https://wiki.debian.org/DebianInstaller/NetbootAssistant
# https://computingforgeeks.com/automated-installation-of-debian-using-pxe-boot/
# https://reintech.io/blog/installing-configuring-pxe-boot-environment-debian-12 
# https://etherarp.net/dnsmasq/index.html
# https://www.debian.org/releases/bookworm/example-preseed.txt 
# append initrd=debian-installer/amd64/initrd.gz language=nl country=NL keymap=us
# apt install --no-install-recommends xfce4 levert 161 pakketten op die binnengehaald worden op een kale debian 02-04-2024 (desktop word niet automatisch gestart - xserver zit er niet bij / login scherm ook niet
