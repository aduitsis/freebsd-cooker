#obviously one can and should override these defaults
HOSTNAME=target.mydomain
IP=1.2.3.4/24
BSD_VERSION=10.1
BSD_ARCH=amd64
TIMEZONE=Europe/Athens
DISTRIBUTIONS=src.txz kernel.txz base.txz lib32.txz doc.txz
MIRROR=ftp.ntua.gr
SIZE_GB=3
SIZE_SWAP=1
SIZE_UFS!= expr $(SIZE_GB) - $(SIZE_SWAP) 
NET_NAME=native_network
MEMORY=512
NCUPS=1

#these should probably remain as-is
RAW_IMAGE=FreeBSD-$(BSD_VERSION)-RELEASE-$(BSD_ARCH).raw
RAW_IMAGE_COMPRESSED=$(RAW_IMAGE).xz


default:
	echo $(DISTRIBUTIONS) $(SIZE_UFS) 

download-image:
	fetch ftp://$(MIRROR)/pub/FreeBSD/releases/VM-IMAGES/$(BSD_VERSION)-RELEASE/$(BSD_ARCH)/Latest/$(RAW_IMAGE_COMPRESSED)

uncompress-image:
	xz -d $(RAW_IMAGE_COMPRESSED)

mount-image:
	mdconfig -f $(RAW_IMAGE) -u98
	mount /dev/md98p3 /mnt

umount:
	- umount /mnt
	mdconfig -d -u98

configure:
	echo hostname=\"$(HOSTNAME)\" > /mnt/etc/rc.conf
	echo ifconfig_em0=\"inet $(IP)\" >> /mnt/etc/rc.conf
	touch /mnt/etc/wall_cmos_clock
	cp /mnt/usr/share/zoneinfo/$(TIMEZONE) /mnt/etc/localtime
	echo dumpdev="AUTO" >> /mnt/etc/rc.conf
	echo kern_securelevel_enable="NO" >> /mnt/etc/rc.conf
	echo kern_securelevel="1" >> /mnt/etc/rc.conf
	echo sshd_enable="YES" >> /mnt/etc/rc.conf
	cp fstab.template /mnt/etc/fstab

vmdk-image:
	vmdktool -v target.vmdk $(RAW_IMAGE)

vmdk:
	vmdktool -v target.vmdk target.ufs
empty:
	dd if=/dev/zero of=target.ufs bs=$(SIZE_SWAP)G count=$(SIZE_GB)
	mdconfig -f target.ufs -u98
	#newfs -O 2 -U -a 4 -b 32768 -d 32768 -e 4096 -f 4096 -g 16384 -h 64 -i 8192 -j -k 6408 -m 8 -o time /dev/md98
	bsdinstall scriptedpart md98 { $(SIZE_UFS)G freebsd-ufs / , auto freebsd-swap }
	mount /dev/md98p2 /mnt
	bsdinstall entropy
	mkdir -p tmp
	mkdir -p distdir
	env DISTRIBUTIONS="src.txz kernel.txz base.txz lib32.txz doc.txz" BSDINSTALL_DISTDIR=`pwd`/distdir BSDINSTALL_DISTSITE=ftp://ftp.gr.freebsd.org/pub/FreeBSD/releases/amd64/10.1-RELEASE bsdinstall distfetch
	### env DISTRIBUTIONS="src.txz kernel.txz base.txz lib32.txz doc.txz" BSDINSTALL_DISTDIR=`pwd`/distdir BSDINSTALL_DISTSITE=ftp://ftp.nl.freebsd.org/pub/FreeBSD/releases/amd64/10.1-RELEASE bsdinstall checksum
	env DISTRIBUTIONS="src.txz kernel.txz base.txz lib32.txz doc.txz" BSDINSTALL_DISTDIR=`pwd`/distdir BSDINSTALL_DISTSITE=ftp://ftp.gr.freebsd.org/pub/FreeBSD/releases/amd64/10.1-RELEASE bsdinstall distextract
	env DISTRIBUTIONS="src.txz kernel.txz base.txz lib32.txz doc.txz" BSDINSTALL_DISTDIR=`pwd`/distdir BSDINSTALL_DISTSITE=ftp://ftp.gr.freebsd.org/pub/FreeBSD/releases/amd64/10.1-RELEASE bsdinstall config


ova:
	cp template.ovf target.ovf
	sed -i .bak -e 's/___NETNAME___/$(NET_NAME)/g' -e 's/___DISK_SIZE___/$(SIZE_GB)/g' -e 's/___MEMORY___/$(MEMORY)/g' -e 's/___HOSTNAME___/$(HOSTNAME)/g' -e 's/___NCPUS___/$(NCPUS)/g' target.ovf
	VMDK_CHECKSUM=`sha1 -q target.vmdk` \
	OVF_CHECKSUM=`sha1 -q target.ovf` ; \
	echo SHA1\(target.vmdk\)= $$VMDK_CHECKSUM > target.mf ; \
	echo SHA1\(target.ovf\)= $$OVF_CHECKSUM >> target.mf ; 
	gtar cvf target.ova target.ovf target.mf target.vmdk

clean:
	- rm `pwd`/distdir/src.txz
	- rm `pwd`/distdir/base.txz
	- rm `pwd`/distdir/lib32.txz
	- rm `pwd`/distdir/doc.txz
	- rm target.ufs
	- rm target.ova
	- rm target.ovf
