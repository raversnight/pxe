#!/bin/bash
# CHATGPT ASSISTED SCRIPT- CHECK FOR ERRORS
# Variabelen
INTERFACE="enp0s8"  # Netwerkinterface naam
STATIC_IP="192.168.1.1"
NETMASK="255.255.255.0"
DHCP_RANGE_START="192.168.1.50"
DHCP_RANGE_END="192.168.1.150"
TFTP_ROOT="/srv/tftp"
DEBIAN_VERSION="bookworm"  # Pas deze aan naar de gewenste Debian versie (bookworm is versie 13)
PRESEED_URL="http://$STATIC_IP/preseed.cfg"
PROXY_URL="http://$STATIC_IP:3128"  # Vervang met de juiste proxy server en poort

# Update en installeer vereiste pakketten
sudo apt update
sudo apt install -y dnsmasq apache2 syslinux-common ipxe wget

# Configureren van statisch IP-adres voor de netwerkinterface
echo "Configureren van statisch IP-adres voor de interface $INTERFACE..."
sudo bash -c "cat > /etc/network/interfaces.d/$INTERFACE <<EOF
auto $INTERFACE
iface $INTERFACE inet static
    address $STATIC_IP
    netmask $NETMASK
EOF"

# Herstart netwerkinterface om de nieuwe instellingen toe te passen
sudo ifdown $INTERFACE && sudo ifup $INTERFACE

# Configuratie voor dnsmasq
echo "Configureren van dnsmasq..."
sudo bash -c "cat > /etc/dnsmasq.conf <<EOF
interface=$INTERFACE
dhcp-range=$DHCP_RANGE_START,$DHCP_RANGE_END,12h
enable-tftp
tftp-root=$TFTP_ROOT
pxe-service=X86-64_EFI, \"Debian Netboot\", ipxe.efi
dhcp-boot=ipxe.efi
EOF"

# Maak TFTP-root directory en download de Debian netboot bestanden
echo "Voorbereiden van de TFTP-server..."
sudo mkdir -p $TFTP_ROOT/debian-installer/$DEBIAN_VERSION
cd $TFTP_ROOT/debian-installer/$DEBIAN_VERSION
sudo wget http://ftp.debian.org/debian/dists/$DEBIAN_VERSION/main/installer-amd64/current/images/netboot/netboot.tar.gz
sudo tar -xzf netboot.tar.gz --strip-components=1
sudo cp /usr/lib/ipxe/ipxe.efi $TFTP_ROOT

# Maak PXE configuratiebestand
sudo mkdir -p $TFTP_ROOT/pxelinux.cfg
sudo bash -c "cat > $TFTP_ROOT/pxelinux.cfg/default <<EOF
DEFAULT vesamenu.c32
PROMPT 0
MENU TITLE PXE Boot Menu
TIMEOUT 600

LABEL debian
  MENU LABEL Install Debian
  KERNEL debian-installer/$DEBIAN_VERSION/linux
  APPEND vga=788 initrd=debian-installer/$DEBIAN_VERSION/initrd.gz auto=true priority=critical url=$PRESEED_URL
EOF"

# Maak preseed bestand
echo "Voorbereiden van preseed bestand..."
sudo bash -c "cat > /var/www/html/preseed.cfg <<EOF
d-i debian-installer/locale string en_US
d-i console-setup/ask_detect boolean false
d-i console-setup/layoutcode string us
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string unassigned-hostname
d-i netcfg/get_domain string unassigned-domain
d-i netcfg/disable_dhcp boolean false
d-i mirror/protocol string http
d-i mirror/country string manual
d-i mirror/http/hostname string ftp.debian.org
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string $PROXY_URL
d-i passwd/root-password password root
d-i passwd/root-password-again password root
d-i passwd/make-user boolean false
d-i clock-setup/utc boolean true
d-i time/zone string UTC
d-i clock-setup/ntp boolean true
d-i partman-auto/method string lvm
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman-auto/choose_recipe select atomic
d-i partman/confirm_write_new_label boolean true
d-i partman/confirm boolean true
d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean true
d-i finish-install/reboot_in_progress note
EOF"

# Configureren van de HTTP-server
echo "Voorbereiden van de HTTP-server..."
sudo mkdir -p /var/www/html/debian
cd /var/www/html/debian
sudo wget http://ftp.debian.org/debian/dists/$DEBIAN_VERSION/main/installer-amd64/current/images/netboot/netboot.tar.gz
sudo tar -xzf netboot.tar.gz --strip-components=1

# Herstart de services
echo "Herstarten van dnsmasq en apache2..."
sudo systemctl restart dnsmasq
sudo systemctl restart apache2

echo "PXE-server configuratie voltooid."
