# FreeBSD Cooker #

Create FreeBSD VM images, ready to be imported by the most popular hypervisors. 
 
### Overview ###

This small project aims to provide a mechanism to fully automate the creation of FreeBSD images, up to the point of providing an Open Virtulization Format image of a FreeBSD installation. All the functionality for this is embedded in a simple Makefile. 

### Synopsis ###

```
#!shell

 #create a UFS Image
 make all 

 #create a ZFS image, 10Gb virtual disk, 1Gb RAM
 make all ZFS=1 HOSTNAME=foo.bar IP=3.4.5.6/24 SIZE_GB=10 MEMORY=1024


```

### Supported Parameters ###

* HOSTNAME: Will be inserted into target's rc.conf.
* IP: In CIDR notation, will be inserted into target's rc.conf.
* SIZE_GB: Size of the entire virtual disk image that will be created.
* SIZE_SWAP: Size of the swap partition inside the virtual disk. Default 1Gb.
* BSD_VERSION: Version of FreeBSD that will be installed, default 10.1.
* BSD_ARCH: Architecture of FreeBSD that will be installed, default amd64.
* TIMEZONE: Timezone that will be setup, default Europe/Athens. 
* MEMORY: Size of RAM in Mbyes, default 512.
* NCPUS: Number of virtual CPUs allocated, default 1.
* PASSWORD_HASH: File containing the password hash of the root password of the image. Default password_hash, see below how to create it. 
* ZFS: If set to any non-empty value (e.g. ZFS=1), the virtual disk will be paritioned and made bootable using a ZFS-based scheme. The default is to create a traditional UFS scheme.

### Password Creation ###

Setting up a password for the image involves the following steps:
1.Run the (provided) mkpasswd.pl script.
2.When prompted for a salt, enter a random string.
3.When prompted for a password, enter the desired password.
4.Copy the SHA-512 hash and paste it inside the password_hash file.

### Workflow ###

1. Create, format and make a bootable raw image, using either UFS or ZFS. 
2. Create metadevice of above image, mount the root partition.
3. Deploy standard FreeBSD Distributions in root partition.
4. Customize installation with hostname, IP address, password, etc.
5. Unmount partition.
6. Convert partition to vmdk format.
7. Create an appropriate OVF manifest and pack it with the vmdk into an OVA archive.

### Acknowledgements ###
I made heavy usage of the ZFS example contained in https://calomel.org/zfs_freebsd_root_install.html, so, many many thanks to these fine folks.


### Author ###
Athanasios Douitsis aduitsis@cpan.org

### License ###
Although there is hardly anything original inside this simple Makefile, everything is release under the same license as FreeBSD itself. In other words, do as you please with it. However, use it at your own risk, there is no liability involved whatsoever.