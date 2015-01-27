HOSTNAME=target.mydomain
IP=1.2.3.4/24


download:
	fetch ftp://ftp.ntua.gr/pub/FreeBSD/releases/VM-IMAGES/10.1-RELEASE/amd64/Latest/FreeBSD-10.1-RELEASE-amd64.raw.xz

uncompress:
	xz -d FreeBSD-10.1-RELEASE-amd64.raw.xz	

mount:
	mdconfig -f FreeBSD-10.1-RELEASE-amd64.raw -u99
	mount /dev/md99p3 /mnt

umount:
	umount /mnt
	mdconfig -d -u99

hostname:
	echo hostname=\"$(HOSTNAME)\" >> /mnt/etc/rc.conf
	echo ifconfig_em0=\"inet $(IP)\" >> /mnt/etc/rc.conf

vmdk:
	vmdktool -v target.vmdk FreeBSD-10.1-RELEASE-amd64.raw	
