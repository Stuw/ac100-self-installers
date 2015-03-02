#!/bin/sh


error()
{
	echo $@
	exit 1
}


detect_target() {
	for dev in /dev/mmcblk*boot0; do
		[ -e "$dev" ] || continue
		echo "${dev:0:12}"
		return 0
	done

	return 1
}

CONFIG_FILE="current.cfg"

clear

KEEP_PT="n"
USE_BOOT_PARTITIONS="n"

echo "Analyzing NV partition table..."
sh ./dump_part_table.sh "$CONFIG_FILE"
if [ $? -ne 0 ]; then
	device="$(detect_target)"
	[ -z "$device" ] && error "Target device was not detected"
	echo "Boot device: $device"

	echo -e "\nFailed to dump current partition table. It is damaged or absent."
	echo -e "\nIf you want to install u-boot anyway say 'y'."
	read -p "Continue (y/n) ? " CONTINUE_WO_PT
	if [ x"$CONTINUE_WO_PT" != "xy" ]; then
		exit
	fi
else
	device=$(head -n1 "$CONFIG_FILE" | sed 's/#Generated_by_script_from_device_//g')
	echo "Boot device: $device"

	echo -e "\nPartition table:"
	sh ./show_partitions.sh "$CONFIG_FILE"
	echo -en "\n"
	read -p "Keep this partition table (y/n) ? " KEEP_PT
	if [ x"$KEEP_PT" != "xy" ] && [ x"$KEEP_PT" != "xn" ]; then
		error Incorrect answer
	fi

	USE_BOOT_PARTITIONS="$KEEP_PT"
	if [ x"$KEEP_PT" == "xy" ]; then
		echo -en "\n\n"
		sh ./boot_partitions.sh --dump $device
		res="$?"
		if [ "$res" -ne "0" ]; then
			echo -e "\nCan't find any boot image. You must configure u-boot yourself later."
			read -p "Continue (y/n) ? "
			if [ x"$REPLY" != "xy" ]; then
			    exit
			fi
			USE_BOOT_PARTITIONS="n"
		fi
	fi
fi


echo -e "\nReady to install u-boot. Old bootloader will be removed."
if [ x"$KEEP_PT" == "xy" ]; then
	echo "Current partition table will be kept."
else
	echo "Current partition table will be destroyed."
fi
read -p "Continue (y/n) ? "
if [ x"$REPLY" != "xy" ]; then
    exit
fi

echo "Installing u-boot..."
sh ./install_bootloader.sh uboot.bin $device || error Failed to install u-boot
# Workaround: erase old PT partition
dd if=/dev/zero of=$device bs=512 count=7168 > /dev/null 2>&1


if [ x"$KEEP_PT" == "xy" ]; then
	echo "Switching to GPT (keep old partitions)..."	
	sh ./apply_partitions_config.sh "$CONFIG_FILE" $device || error Failed to switch to GPT

	if [ x"$USE_BOOT_PARTITIONS" == "xy" ]; then
		echo "Configuring u-boot..."
		sh ./boot_partitions.sh --apply $device || error Failed to configure u-boot
	fi
else
	echo "Switching to GPT (remove all partitions)..."	
	parted $device << EOF
unit s
mklabel gpt
quit
EOF
fi

echo "Done."

