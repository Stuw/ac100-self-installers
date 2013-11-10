#!/bin/sh


error()
{
	echo $@
	exit 1
}


echo "Analyzing NV partition table..."
sh ./dump_part_table.sh current.cfg || error Failed to dump current partition table

device=$(head -n1 current.cfg | sed 's/#Generated_by_script_from_device_//g')
echo "Boot device: $device"

sh ./boot_partitions.sh --dump $device || error Failed to dump boot partitions

read -p "Continue (y/n) ? "
if [ x"$REPLY" != "xy" ]; then
    exit
fi

echo "Installing u-boot..."
sh ./install_bootloader.sh uboot.bin $device || error Failed to install u-boot

echo "Switching to GPT..."	
sh ./apply_partitions_config.sh current.cfg $device || error Failed to switch to GPT

echo "Configuring u-boot..."
sh ./boot_partitions.sh --apply $device || error Failed to configure u-boot

echo "Done."

