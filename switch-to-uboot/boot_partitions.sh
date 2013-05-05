#!/bin/sh

dump_partition()
{
    name="$1"
    dev="$2"
    res=0
    
    rm -rf "$name"
    mkdir "$name"
    cd "$name"
    abootimg -x "$dev" > /dev/null 2>&1 || res=1
    cd ..
    
    return $res
}

dump_boot_partitions()
{
    device="$1"
    dump_partition sos "${device}p1" || (echo sos fail; rm -rf sos)
    dump_partition lnx "${device}p2" || (echo lnx fail; rm -rf lnx)
}


configure_uboot()
{
    device="$1"
 
    echo "mkimage ... -d initrd.img initrd-uboot"
    
    mkfs.ext2 -F "$device" >/dev/null || exit 1
    mkdir lnx/mnt
    #mount "$device" lnx/mnt || exit 1
    mkdir lnx/mnt/boot || (umount lnx/mnt; exit 1)
    cp lnx/zImage lnx/mnt/boot/zImage || (umount lnx/mnt; exit 1)
    cp lnx/initrd.img lnx/mnt/boot/initrd-uboot || (umount lnx/mnt; exit 1)
    
    cmdline=$(cat lnx/bootimg.cfg | grep cmdline | sed "s/cmdline = //")

    cfg="lnx/mnt/boot/boot.cmd"
    echo "echo === boot.scr: loading from SOS partition ===
mmc dev 0
setenv bootargs '$cmdline'
ext2load mmc 0 0x1000000 /boot/zImage
ext2load mmc 0 0x2200000 /boot/initrd-uboot
bootz 0x1000000 0x2200000" > $cfg

    echo "mkimage ... -d boot.cmd boot.scr"

    umount lnx/mnt
}


case $1 in
	"--dump") dump_boot_partitions /dev/mmcblk1 ;;
	"--apply") configure_uboot mmcblkY ;;
	*) dump_boot_partitions ../mmcblkX ;;
esac
