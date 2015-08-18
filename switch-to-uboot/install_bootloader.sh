#!/bin/bash


install_bootloader()
{
	bootloader="$1"
	device="$2"

	bct="ac100.bct"
	new_bct="new.bct"
	bct_config="bct.cfg"

	bct_dev="${device}boot0"
	echo "Dump configuration..."
	dd if="$bct_dev" of="$bct" bs=4080 count=1
	if [ $? -ne "0" ]; then
   		echo "Failed to copy bct to file"
		return 1
	fi

	echo "Version       = 0x00020001;
Bctcopy       = 1;
Bctfile       = ${bct};
BootLoader = ${bootloader},0x00108000,0x00108000,Complete;" >> $bct_config

	cbootimage --debug -o0x800c0075 "$bct_config" "${new_bct}"
	if [ $? -ne "0" ]; then
		echo "Failed to gen new BCT."
		return 1
	fi

	echo 0 > "/sys/block/$(basename ${device})boot0/force_ro"
	echo 0 > "/sys/block/$(basename ${device})boot1/force_ro"

	dd if=/dev/zero of=${device}boot0 2>/dev/null
	dd if=/dev/zero of=${device}boot1 2>/dev/null

	dd if=${new_bct} of=${bct_dev}
	if [ $? -ne "0" ]; then
		echo "Failed to write new BCT."
		return 1
	fi

	echo 1 > "/sys/block/$(basename ${device})boot0/force_ro"
	echo 1 > "/sys/block/$(basename ${device})boot1/force_ro"
}


install_bootloader "$1" "$2"

