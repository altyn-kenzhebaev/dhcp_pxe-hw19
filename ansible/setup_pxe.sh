
#!/bin/bash

echo Install PXE server
yum -y install epel-release

yum -y install dhcp-server tftp-server nfs-utils

#firewall-cmd --add-service=tftp
# disable selinux or permissive
setenforce 0

almalinux_version=9.2

cat >/etc/dhcp/dhcpd.conf <<EOF
option space pxelinux;
option pxelinux.magic code 208 = string;
option pxelinux.configfile code 209 = text;
option pxelinux.pathprefix code 210 = text;
option pxelinux.reboottime code 211 = unsigned integer 32;
option architecture-type code 93 = unsigned integer 16;

subnet 10.0.0.0 netmask 255.255.255.0 {
	#option routers 10.0.0.254;
	range 10.0.0.100 10.0.0.120;

	class "pxeclients" {
	  match if substring (option vendor-class-identifier, 0, 9) = "PXEClient";
	  next-server 10.0.0.20;

	  if option architecture-type = 00:07 {
	    filename "uefi/shim.efi";
	    } else {
	    filename "pxelinux/pxelinux.0";
	  }
	}
}
EOF

systemctl --now enable dhcpd

yum -y install syslinux-tftpboot.noarch
mkdir /var/lib/tftpboot/pxelinux
cp /tftpboot/pxelinux.0 /var/lib/tftpboot/pxelinux
cp /tftpboot/libutil.c32 /var/lib/tftpboot/pxelinux
cp /tftpboot/menu.c32 /var/lib/tftpboot/pxelinux
cp /tftpboot/libmenu.c32 /var/lib/tftpboot/pxelinux
cp /tftpboot/ldlinux.c32 /var/lib/tftpboot/pxelinux
cp /tftpboot/vesamenu.c32 /var/lib/tftpboot/pxelinux

mkdir /var/lib/tftpboot/pxelinux/pxelinux.cfg

cat > /var/lib/tftpboot/pxelinux/pxelinux.cfg/default <<EOF
default menu
prompt 0
timeout 100

MENU TITLE Demo PXE setup

LABEL linux
  menu label ^Install system
  kernel images/Almalinux-9/vmlinuz
  initrd images/Almalinux-9/initrd.img 
  append ip=enp0s3:dhcp inst.repo=nfs:10.0.0.20:/mnt/almalinux9-install
LABEL linux-auto
  menu label ^Auto install system
  menu default
  kernel images/Almalinux-9/vmlinuz
  initrd images/Almalinux-9/initrd.img
  append ip=enp0s3:dhcp inst.ks=nfs:10.0.0.20:/home/vagrant/cfg/ks.cfg inst.repo=nfs:10.0.0.20:/mnt/almalinux9-install
LABEL vesa
  menu label Install system with ^basic video driver
  kernel images/Almalinux-9/vmlinuz
  append initrd=images/Almalinux-9/initrd.img ip=dhcp inst.xdriver=vesa nomodeset
LABEL rescue
  menu label ^Rescue installed system
  kernel images/Almalinux-9/vmlinuz
  append initrd=images/Almalinux-9/initrd.img rescue
LABEL local
  menu label Boot from ^local drive
  localboot 0xffff
EOF

mkdir -p /var/lib/tftpboot/pxelinux/images/Almalinux-9/
curl -O http://mirror.ps.kz/almalinux/$almalinux_version/BaseOS/x86_64/os/images/pxeboot/initrd.img
curl -O http://mirror.ps.kz/almalinux/$almalinux_version/BaseOS/x86_64/os/images/pxeboot/vmlinuz
cp {vmlinuz,initrd.img} /var/lib/tftpboot/pxelinux/images/Almalinux-9/

mkdir /root/packages
cd /root/packages/
yum install yum-utils -y 
yumdownloader shim-x64 grub2-efi-x64
rpm2cpio grub2-efi-x64-*.rpm | cpio -dimv
rpm2cpio shim-x64-*.rpm | cpio -dimv
mkdir /var/lib/tftpboot/uefi
cp /root/packages/boot/efi/EFI/almalinux/grubx64.efi /var/lib/tftpboot/uefi/
cp /root/packages/boot/efi/EFI/almalinux/shim.efi /var/lib/tftpboot/uefi/
cat > /var/lib/tftpboot/uefi/grub.cfg <<EOF
set default=0
set timeout=10
insmod efinet
menuentry  'Automatic Install Almalinux 9.2' --class fedora --class gnu-linux --class gnu --class os {
   linuxefi pxelinux/images/Almalinux-9/vmlinuz ip=dhcp inst.ks=nfs:10.0.0.20:/home/vagrant/cfg/ks.cfg inst.repo=nfs:10.0.0.20:/mnt/almalinux9-install 
   initrdefi pxelinux/images/Almalinux-9/initrd.img
}
menuentry  'Manual Install Almalinux 9.2' --class fedora --class gnu-linux --class gnu --class os {
   linuxefi pxelinux/images/Almalinux-9/vmlinuz ip=dhcp inst.repo=nfs:10.0.0.20:/mnt/almalinux9-install
   initrdefi pxelinux/images/Almalinux-9/initrd.img
}
EOF
useradd -s /sbin/nologin tftp
chown -R tftp:tftp /var/lib/tftpboot/
chmod -R 750 /var/lib/tftpboot/
sed -i -e 's|\/var\/lib\/tftpboot.*|\/var\/lib\/tftpboot \-u tftp \-p|g' /usr/lib/systemd/system/tftp.service
systemctl daemon-reload
systemctl --now enable tftp.service

# Setup NFS auto install
# 

# create exptra space because ISO does not fit to VM rootfs
#mkfs.xfs /dev/sdb
#mkdir /mnt/extraspace
#mount /dev/sdb /mnt/extraspace
#chown vagrant.vagrant  /mnt/extraspace

mkdir /mnt/almalinux9-install
mount -t iso9660  /dev/sr0 /mnt/almalinux9-install
echo '/mnt/almalinux9-install *(ro)' > /etc/exports
systemctl start nfs-server.service



mkdir /home/vagrant/cfg
cat > /home/vagrant/cfg/ks.cfg <<EOF
#version=RHEL9
ignoredisk --only-use=sda
autopart --type=lvm
# Partition clearing information
clearpart --all --initlabel --drives=sda
# Use graphical install
graphical
# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8
#repo
#url --url=http://ftp.mgts.by/pub/CentOS/${centos_version}/BaseOS/x86_64/os/

# Network information
network  --bootproto=dhcp --device=enp0s3 --noipv6 --activate
network  --hostname=localhost.localdomain
# Root password: vagrant
rootpw --iscrypted $6$fd1TNImp4PPL5RQp$HZSsu0TG9R9M0AhBae4j4PS0s.aA7AwLNsNJqKKqMa7an8Tmgcpz.c0Pt8QXqbsmZhFJKpzuJjm2FNizy9PsC1
# Run the Setup Agent on first boot
firstboot --enable
# Do not configure the X Window System
skipx
# System services
services --enabled="chronyd"
# System timezone
timezone Asia/Bishkek
# Add user: vagrant password: vagrant
user --groups=wheel --name=vagrant --password=$6$8rFj7f9nZNtkJGWD$Bbghspvg4ht3NLS77ELeOQk0eCAjGK0vfhHeY00wX2XnRo3Hl2SdbV8JD0rS1sFT50mllzcHhVA/ENazpieiC0 --iscrypted --gecos="vagrant"

%packages --ignoremissing
@^minimal-environment
kexec-tools

%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end

EOF

chown -R vagrant.vagrant /home/vagrant/cfg
echo '/home/vagrant/cfg *(ro)' >> /etc/exports
systemctl reload nfs-server.service
iptables -t nat -A POSTROUTING ! -d 192.168.0.0/16 -o eth0 -j MASQUERADE
sysctl net.ipv4.conf.all.forwarding=1