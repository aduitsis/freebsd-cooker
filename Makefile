#obviously one can and should override these defaults
HOSTNAME=target.mydomain
IP=DHCP
IPV6="inet6 accept_rtadv"
### example: IP=1.2.3.4/24
BSD_VERSION=10.1
BSD_ARCH=amd64
TIMEZONE=Europe/Athens
#DISTRIBUTIONS=src.txz kernel.txz base.txz lib32.txz 
DISTRIBUTIONS=kernel.txz base.txz
MIRROR=ftp.gr.freebsd.org
SIZE_GB=3
SIZE_SWAP=1
SIZE_UFS!= expr $(SIZE_GB) - $(SIZE_SWAP) 
NET_NAME=native_network
MEMORY=512
NCPUS=1
PASSWORD_HASH=password_hash
NAMESERVER="8.8.8.8"
NAMESERVER+="8.8.4.4"
PKGNG=vim-lite 
PKGNG+=puppet
PUPPET=init.pp

#these should probably remain as-is
RAW_IMAGE=FreeBSD-$(BSD_VERSION)-RELEASE-$(BSD_ARCH).raw
RAW_IMAGE_COMPRESSED=$(RAW_IMAGE).xz
MD_NUMBER=98
ZROOT=zroot
DISTDIR=distdir-$(BSD_VERSION)-$(BSD_ARCH)
DISTSITE=ftp://$(MIRROR)/pub/FreeBSD/releases/$(BSD_ARCH)/$(BSD_VERSION)-RELEASE


#do not touch
MODE=ufs
ZPOOL_DIR=
.if (defined(ZFS)) 
MODE=zfs
ZPOOL_DIR=$(ZROOT)/
.endif




show:
	@echo distributions=$(DISTRIBUTIONS) size_ufs=$(SIZE_UFS) zpool_dir=$(ZPOOL_DIR) mode=$(MODE) ip=$(IP_RC) common_settings=$(COMMON_SETTINGS) ns=$(NAMESERVER)

#################################################################################

COMMON_SETTINGS+=set_hostname
set_hostname:
	echo hostname=\"$(HOSTNAME)\" > /mnt/$(ZPOOL_DIR)etc/rc.conf

.if ! $(IP) == "DHCP"
IP_RC=inet $(IP)
.else
IP_RC=$(IP)
.endif
COMMON_SETTINGS+=ifconfig
ifconfig:
	echo ifconfig_em0=\"$(IP_RC)\" >> /mnt/$(ZPOOL_DIR)etc/rc.conf

.if $(IPV6) != "" 
COMMON_SETTINGS+=ipv6
.endif
ipv6:
	echo ifconfig_em0_ipv6=\"$(IPV6)\" >> /mnt/$(ZPOOL_DIR)etc/rc.conf

.if (defined(DEFAULTROUTER))
COMMON_SETTINGS+=defaultrouter
.endif
defaultrouter:
	echo defaultrouter=\"$(DEFAULTROUTER)\" >> /mnt/$(ZPOOL_DIR)etc/rc.conf

COMMON_SETTINGS+=cmos
cmos:
	touch /mnt/$(ZPOOL_DIR)etc/wall_cmos_clock

COMMON_SETTINGS+=timezone
timezone:
	cp /mnt/$(ZPOOL_DIR)usr/share/zoneinfo/$(TIMEZONE) /mnt/$(ZPOOL_DIR)etc/localtime

COMMON_SETTINGS+=dumpdev
dumpdev:
	echo dumpdev="AUTO" >> /mnt/$(ZPOOL_DIR)etc/rc.conf

COMMON_SETTINGS+=kern_securelevel
kern_securelevel:
	echo kern_securelevel_enable="NO" >> /mnt/$(ZPOOL_DIR)etc/rc.conf
	echo kern_securelevel="1" >> /mnt/$(ZPOOL_DIR)etc/rc.conf

COMMON_SETTINGS+=sshd_enable
sshd_enable:
	echo sshd_enable="YES" >> /mnt/$(ZPOOL_DIR)etc/rc.conf

COMMON_SETTINGS+=set_password
set_password:
	cat $(PASSWORD_HASH) | chroot /mnt/$(ZPOOL_DIR) pw usermod root -H 0 

.if $(NAMESERVER) != ""
COMMON_SETTINGS+=set_resolv_conf
.endif
set_resolv_conf:
	for i in $(NAMESERVER); do echo nameserver $$i >> /mnt/$(ZPOOL_DIR)etc/resolv.conf ; done

.if $(PKGNG) != ""
COMMON_SETTINGS+=pkgng
.endif
pkgng:
	env ASSUME_ALWAYS_YES=true chroot /mnt/$(ZPOOL_DIR) pkg bootstrap
	env ASSUME_ALWAYS_YES=true chroot /mnt/$(ZPOOL_DIR) pkg install $(PKGNG) 

.if $(PUPPET) != ""
COMMON_SETTINGS+=puppet
.endif
puppet:
	mkdir -p /mnt/$(ZPOOL_DIR)root/freebsd-cooker/
	cp $(PUPPET) /mnt/$(ZPOOL_DIR)root/freebsd-cooker/
	for i in $(PUPPET); do chroot /mnt/$(ZPOOL_DIR) puppet apply /root/freebsd-cooker/$$i ; done

common_settings: $(COMMON_SETTINGS)

#################################################################################

vmdk-image:
	vmdktool -v target.vmdk $(RAW_IMAGE)

vmdk:
	vmdktool -v target.vmdk target.disk

ova:
	cp template.ovf target.ovf
	sed -i .bak -e 's/___NETNAME___/$(NET_NAME)/g' -e 's/___DISK_SIZE___/$(SIZE_GB)/g' -e 's/___MEMORY___/$(MEMORY)/g' -e 's/___HOSTNAME___/$(HOSTNAME)/g' -e 's/___NCPUS___/$(NCPUS)/g' target.ovf
	VMDK_CHECKSUM=`sha1 -q target.vmdk` \
	OVF_CHECKSUM=`sha1 -q target.ovf` ; \
	echo SHA1\(target.vmdk\)= $$VMDK_CHECKSUM > target.mf ; \
	echo SHA1\(target.ovf\)= $$OVF_CHECKSUM >> target.mf ; 
	gtar cvf target.ova target.ovf target.mf target.vmdk

#################################################################################

clean:
	- rm `pwd`/$(DISTDIR)/src.txz
	- rm `pwd`/$(DISTDIR)/base.txz
	- rm `pwd`/$(DISTDIR)/lib32.txz
	- rm `pwd`/$(DISTDIR)/doc.txz
	- rm target.disk
	- rm target.ova
	- rm target.ovf

#################################################################################


emptyimage:
	dd if=/dev/zero of=target.disk bs=1G count=$(SIZE_GB)

metadevice:
	mdconfig -f target.disk -u$(MD_NUMBER)

delete_metadevice:
	mdconfig -d -u$(MD_NUMBER)

ufs_partition:
	#newfs -O 2 -U -a 4 -b 32768 -d 32768 -e 4096 -f 4096 -g 16384 -h 64 -i 8192 -j -k 6408 -m 8 -o time /dev/md$(MD_NUMBER)
	bsdinstall scriptedpart md$(MD_NUMBER) { $(SIZE_UFS)G freebsd-ufs / , auto freebsd-swap }

ufs_mount:
	mount /dev/md$(MD_NUMBER)p2 /mnt

ufs_umount:
	- umount /mnt
	
entropy:
	env BSDINSTALL_CHROOT=/mnt/$(ZPOOL_DIR) bsdinstall entropy

distfetch-bsdinstall:
	mkdir -p $(DISTDIR)
	env DISTRIBUTIONS="$(DISTRIBUTIONS)" BSDINSTALL_DISTDIR=`pwd`/$(DISTDIR) BSDINSTALL_DISTSITE=ftp://$(MIRROR)/pub/FreeBSD/releases/$(BSD_ARCH)/$(BSD_VERSION)-RELEASE bsdinstall distfetch

distfetch-manual: 
	cd $(DISTDIR) ; for i in $(DISTRIBUTIONS); do fetch -m $(DISTSITE)/$$i ; done

DISTFETCH_METHOD=manual
distfetch: distfetch-$(DISTFETCH_METHOD) 

distextract:
	env BSDINSTALL_CHROOT=/mnt/$(ZPOOL_DIR) DISTRIBUTIONS="$(DISTRIBUTIONS)" BSDINSTALL_DISTDIR=`pwd`/$(DISTDIR) BSDINSTALL_DISTSITE=ftp://$(MIRROR)/pub/FreeBSD/releases/$(BSD_ARCH)/$(BSD_VERSION)-RELEASE bsdinstall distextract

bsdinstall_config:
	env BSDINSTALL_CHROOT=/mnt/$(ZPOOL_DIR) DISTRIBUTIONS="$(DISTRIBUTIONS)" BSDINSTALL_DISTDIR=`pwd`/$(DISTDIR) BSDINSTALL_DISTSITE=ftp://$(MIRROR)/pub/FreeBSD/releases/$(BSD_ARCH)/$(BSD_VERSION)-RELEASE bsdinstall config

ufs_fstab:
	cp fstab.template /mnt/etc/fstab

create_ufs: emptyimage metadevice ufs_partition ufs_mount entropy distfetch distextract bsdinstall_config ufs_fstab common_settings ufs_umount delete_metadevice

zpart:	
	gpart create -s gpt md$(MD_NUMBER)	
	gpart add -a 4k -s 512k -t freebsd-boot md$(MD_NUMBER)
	# this will fill the rest of the image
	gpart add -a 4k -t freebsd-zfs -l gpt_root md$(MD_NUMBER)
	gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 md$(MD_NUMBER)
	zpool create -f -o altroot=/mnt -o cachefile=/var/tmp/zpool.cache zroot /dev/md$(MD_NUMBER)p2
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

create_zfs: emptyimage metadevice zpart entropy distfetch distextract bsdinstall_config common_settings zfs_settings zfs_umount delete_metadevice

zfs_settings: 
	cp /var/tmp/zpool.cache /mnt/$(ZPOOL_DIR)/boot/zfs/zpool.cache
	cd /mnt/$(ZPOOL_DIR) ; ln -s usr/home home
	echo 'zfs_enable="YES"' >> /mnt/$(ZPOOL_DIR)/etc/rc.conf
	echo 'zfs_load="YES"' >> /mnt/$(ZPOOL_DIR)/boot/loader.conf
	echo 'vfs.root.mountfrom="zfs:zroot"' >> /mnt/$(ZPOOL_DIR)/boot/loader.conf
	echo "# use gpt ids instead of gptids or disks idents"
	echo 'kern.geom.label.disk_ident.enable="0"' >> /mnt/$(ZPOOL_DIR)/boot/loader.conf
	echo 'kern.geom.label.gpt.enable="1"' >> /mnt/$(ZPOOL_DIR)/boot/loader.conf
	echo 'kern.geom.label.gptid.enable="0"' >> /mnt/$(ZPOOL_DIR)/boot/loader.conf
	touch /mnt/$(ZPOOL_DIR)/etc/fstab

zfs_umount:
	# to unmount the filesystem before packaging
	zpool export zroot
	# if I wanted to reimport I'd zpool import -o altroot=/mnt [the numeric id] or zroot

create: create_$(MODE) 

all: create vmdk ova


###########################################################
# the below section is no longer actively used, kept here 
# lest it is used in the future
# #########################################################
download-image:
	fetch ftp://$(MIRROR)/pub/FreeBSD/releases/VM-IMAGES/$(BSD_VERSION)-RELEASE/$(BSD_ARCH)/Latest/$(RAW_IMAGE_COMPRESSED)

uncompress-image:
	xz -d $(RAW_IMAGE_COMPRESSED)

mount-image:
	mdconfig -f $(RAW_IMAGE) -u$(MD_NUMBER)
	mount /dev/md$(MD_NUMBER)p3 /mnt
