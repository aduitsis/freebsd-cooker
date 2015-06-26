#obviously one can and should override these defaults
HOSTNAME=target.mydomain
IP=1.2.3.4/24
BSD_VERSION=10.1
BSD_ARCH=amd64
TIMEZONE=Europe/Athens
DISTRIBUTIONS=src.txz kernel.txz base.txz lib32.txz doc.txz
MIRROR=ftp.gr.freebsd.org
SIZE_GB=3
SIZE_SWAP=1
SIZE_UFS!= expr $(SIZE_GB) - $(SIZE_SWAP) 
NET_NAME=native_network
MEMORY=512
NCUPS=1

#these should probably remain as-is
RAW_IMAGE=FreeBSD-$(BSD_VERSION)-RELEASE-$(BSD_ARCH).raw
RAW_IMAGE_COMPRESSED=$(RAW_IMAGE).xz
MD_NUMBER=98


default:
	echo $(DISTRIBUTIONS) $(SIZE_UFS) 

download-image:
	fetch ftp://$(MIRROR)/pub/FreeBSD/releases/VM-IMAGES/$(BSD_VERSION)-RELEASE/$(BSD_ARCH)/Latest/$(RAW_IMAGE_COMPRESSED)

uncompress-image:
	xz -d $(RAW_IMAGE_COMPRESSED)

mount-image:
	mdconfig -f $(RAW_IMAGE) -u$(MD_NUMBER)
	mount /dev/md$(MD_NUMBER)p3 /mnt

umount:
	- umount /mnt
	mdconfig -d -u$(MD_NUMBER)

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
	dd if=/dev/zero of=target.ufs bs=1G count=$(SIZE_GB)
	mdconfig -f target.ufs -u$(MD_NUMBER)
	#newfs -O 2 -U -a 4 -b 32768 -d 32768 -e 4096 -f 4096 -g 16384 -h 64 -i 8192 -j -k 6408 -m 8 -o time /dev/md$(MD_NUMBER)
	bsdinstall scriptedpart md$(MD_NUMBER) { $(SIZE_UFS)G freebsd-ufs / , auto freebsd-swap }
	mount /dev/md$(MD_NUMBER)p2 /mnt
	bsdinstall entropy
	mkdir -p tmp
	mkdir -p distdir
	env DISTRIBUTIONS="$(DISTRIBUTIONS)" BSDINSTALL_DISTDIR=`pwd`/distdir BSDINSTALL_DISTSITE=ftp://$(MIRROR)/pub/FreeBSD/releases/amd64/10.1-RELEASE bsdinstall distfetch
	### env DISTRIBUTIONS="src.txz kernel.txz base.txz lib32.txz doc.txz" BSDINSTALL_DISTDIR=`pwd`/distdir BSDINSTALL_DISTSITE=ftp://ftp.nl.freebsd.org/pub/FreeBSD/releases/amd64/10.1-RELEASE bsdinstall checksum
	env DISTRIBUTIONS="$(DISTRIBUTIONS)" BSDINSTALL_DISTDIR=`pwd`/distdir BSDINSTALL_DISTSITE=ftp://$(MIRROR)/pub/FreeBSD/releases/amd64/10.1-RELEASE bsdinstall distextract
	env DISTRIBUTIONS="$(DISTRIBUTIONS)" BSDINSTALL_DISTDIR=`pwd`/distdir BSDINSTALL_DISTSITE=ftp://$(MIRROR)/pub/FreeBSD/releases/amd64/10.1-RELEASE bsdinstall config


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

zpart:	
	gpart create -s gpt md90	
	gpart add -a 4k -s 512k -t freebsd-boot md90
	# this will fill the rest of the image
	gpart add -a 4k -t freebsd-zfs -l gpt_root md90
	gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 md90
	zpool create -f -o altroot=/mnt -o cachefile=/var/tmp/zpool.cache zroot /dev/md90p2
	#zpool export zroot
	#zpool import -o altroot=/mnt -o cachefile=/var/tmp/zpool.cache zroot
	# a big thanks to this: https://calomel.org/zfs_freebsd_root_install.html
	zpool set bootfs=zroot zroot
	zpool set listsnapshots=on zroot
	zpool set autoreplace=on zroot
	zfs set checksum=fletcher4 zroot
	zfs set compression=lz4 zroot
	zfs set atime=off zroot
	zfs set copies=3 zroot
	zfs create -V 1G zroot/swap
	zfs set org.freebsd:swap=on zroot/swap
	# install DISTRIBUTIONS here
	bsdinstall entropy
	env BSDINSTALL_CHROOT=/mnt/zroot DISTRIBUTIONS="$(DISTRIBUTIONS)" BSDINSTALL_DISTDIR=`pwd`/distdir bsdinstall distextract
	env BSDINSTALL_CHROOT=/mnt/zroot DISTRIBUTIONS="$(DISTRIBUTIONS)" BSDINSTALL_DISTDIR=`pwd`/distdir bsdinstall config
	cp /var/tmp/zpool.cache /mnt/zroot/boot/zfs/zpool.cache
	cd /mnt/zroot ; ln -s usr/home home
	echo 'zfs_enable="YES"' >> /mnt/zroot/etc/rc.conf
	echo 'zfs_load="YES"' >> /mnt/zroot/boot/loader.conf
	echo 'vfs.root.mountfrom="zfs:zroot"' >> /mnt/zroot/boot/loader.conf
	echo "# use gpt ids instead of gptids or disks idents"
	echo 'kern.geom.label.disk_ident.enable="0"' >> /mnt/zroot/boot/loader.conf
	echo 'kern.geom.label.gpt.enable="1"' >> /mnt/zroot/boot/loader.conf
	echo 'kern.geom.label.gptid.enable="0"' >> /mnt/zroot/boot/loader.conf
	touch /mnt/zroot/etc/fstab
	# to unmount the filesystem before packaging
	zpool export zroot
