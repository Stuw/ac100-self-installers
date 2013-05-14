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
    dump_partition sos "${device}p1" || (echo No boot image in SOS partition; rm -rf sos)
    dump_partition lnx "${device}p2" || (echo No boot image in LNX partition; rm -rf lnx; exit 1)
}

_mount()
{
    device=$1
    mnt_point=$2

    mkdir -p ${mnt_point}/sos || return 1
    mkdir -p ${mnt_point}/lnx || return 1

    res=0
    mount ${device}p1 ${mnt_point}/sos || return 1
    mount ${device}p2 ${mnt_point}/lnx || (umount ${mnt_point}/sos; res=1)

    return $res
}

_umount()
{
    mnt_point=$1
    umount ${mnt_point}/sos
    umount ${mnt_point}/lnx
}

configure_uboot()
{
    device="${1}"
 
    mkimage -n MyRamDisk -A arm -O linux -T ramdisk -C gzip -d lnx/initrd.img lnx/initrd-uboot
    
    mnt_point=lnx/mnt
    mkdir $mnt_point

    mkfs.ext2 -F "${device}p1" >/dev/null || exit 1
    mkfs.ext2 -F "${device}p2" >/dev/null || exit 1

    _mount "$device" $mnt_point || exit 1

    mkdir ${mnt_point}/sos/boot || (_umount lnx/mnt; exit 1)
    mkdir ${mnt_point}/lnx/boot || (_umount lnx/mnt; exit 1)

    cp lnx/zImage ${mnt_point}/lnx/boot/zImage || (umount lnx/mnt; exit 1)
    cp lnx/initrd-uboot ${mnt_point}/lnx/boot/initrd-uboot || (umount lnx/mnt; exit 1)
    
    cmdline=$(cat lnx/bootimg.cfg | grep cmdline | sed "s/cmdline = //")

    cfg="${mnt_point}/sos/boot/boot.cmd"
    echo "echo === boot.scr: loading from SOS partition ===
mmc dev 0
setenv bootargs '$cmdline'
ext2load mmc 0:2 0x1000000 /boot/zImage
ext2load mmc 0:2 0x2200000 /boot/initrd-uboot
bootz 0x1000000 0x2200000" > $cfg

    mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n "myscript" -d "$cfg" ${mnt_point}/sos/boot/boot.scr

    _umount $mnt_point
}


case $1 in
	"--dump") dump_boot_partitions $2 ;;
	"--apply") configure_uboot $2 ;;
	*) echo "Usage: $0 <--dump device|--apply device>" ;;
esac

