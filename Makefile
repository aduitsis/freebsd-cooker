#obviously one can and should override these defaults
HOSTNAME=target.mydomain
IP=1.2.3.4/24
BSD_VERSION=10.1
BSD_ARCH=amd64
TIMEZONE=Europe/Athens
DISTRIBUTIONS=src.txz kernel.txz base.txz lib32.txz doc.txz
MIRROR=ftp.ntua.gr

#these should probably remain as-is
RAW_IMAGE=FreeBSD-$(BSD_VERSION)-RELEASE-$(BSD_ARCH).raw
RAW_IMAGE_COMPRESSED=$(RAW_IMAGE).xz


default:
	echo $(DISTRIBUTIONS)

download:
	fetch ftp://$(MIRROR)/pub/FreeBSD/releases/VM-IMAGES/$(BSD_VERSION)-RELEASE/$(BSD_ARCH)/Latest/$(RAW_IMAGE_COMPRESSED)

uncompress:
	xz -d $(RAW_IMAGE_COMPRESSED)

mount:
	mdconfig -f $(RAW_IMAGE) -u99
	mount /dev/md99p3 /mnt

umount:
	umount /mnt
	mdconfig -d -u99

configure:
	echo hostname=\"$(HOSTNAME)\" >> /mnt/etc/rc.conf
	echo ifconfig_em0=\"inet $(IP)\" >> /mnt/etc/rc.conf
	touch /mnt/etc/wall_cmos_clock
	cp /mnt/usr/share/zoneinfo/$(TIMEZONE) /mnt/etc/localtime
	echo dumpdev="AUTO" >> /mnt/etc/rc.conf
	echo kern_securelevel_enable="NO" >> /mnt/etc/rc.conf
	echo kern_securelevel="1" >> /mnt/etc/rc.conf
	echo sshd_enable="YES" >> /mnt/etc/rc.conf
	cp fstab.template /mnt/etc/fstab

vmdk:
	vmdktool -v target.vmdk $(RAW_IMAGE)

empty:
	dd if=/dev/zero of=root.ufs bs=1G count=5
	mdconfig -f root.ufs -u99
	#newfs -O 2 -U -a 4 -b 32768 -d 32768 -e 4096 -f 4096 -g 16384 -h 64 -i 8192 -j -k 6408 -m 8 -o time /dev/md99
	bsdinstall scriptedpart md99 { 1G freebsd-swap , auto freebsd-ufs / }
	mount /dev/md99p2 /mnt
	bsdinstall entropy
	mkdir -p tmp
	mkdir -p distdir
	env DISTRIBUTIONS="src.txz kernel.txz base.txz lib32.txz doc.txz" BSDINSTALL_DISTDIR=`pwd`/distdir BSDINSTALL_DISTSITE=ftp://ftp.nl.freebsd.org/pub/FreeBSD/releases/amd64/10.1-RELEASE bsdinstall distfetch
	### env DISTRIBUTIONS="src.txz kernel.txz base.txz lib32.txz doc.txz" BSDINSTALL_DISTDIR=`pwd`/distdir BSDINSTALL_DISTSITE=ftp://ftp.nl.freebsd.org/pub/FreeBSD/releases/amd64/10.1-RELEASE bsdinstall checksum
	env DISTRIBUTIONS="src.txz kernel.txz base.txz lib32.txz doc.txz" BSDINSTALL_DISTDIR=`pwd`/distdir BSDINSTALL_DISTSITE=ftp://ftp.nl.freebsd.org/pub/FreeBSD/releases/amd64/10.1-RELEASE bsdinstall distextract
	env DISTRIBUTIONS="src.txz kernel.txz base.txz lib32.txz doc.txz" BSDINSTALL_DISTDIR=`pwd`/distdir BSDINSTALL_DISTSITE=ftp://ftp.nl.freebsd.org/pub/FreeBSD/releases/amd64/10.1-RELEASE bsdinstall config

