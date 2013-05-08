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
	bct_dump "$bct_dev" > "$bct_config"
	if [ $? -ne "0" ]; then
		echo "Failed to dump BCT config."
		return 1
	fi

	echo 'BootLoader = ${bootloader},0x00108000,0x00108000,Complete;' >> $bct_config

	echo 0 > "/sys/block/$(basename ${device})boot0/force_ro"
	echo 0 > "/sys/block/$(basename ${device})boot1/force_ro"

	cbootimage -d "$bct_config" "${new_bct}"
	if [ $? -ne "0" ]; then
		echo "Failed to gen new BCT."
		return 1
	fi

	dd if=/dev/zero of==${device}boot0 2>/dev/null
	dd if=/dev/zero of==${device}boot1 2>/dev/null

	dd if=${new_bct} of=${bct_dev}
	if [ $? -ne "0" ]; then
		echo "Failed to write new BCT."
		return 1
	fi

	echo 1 > "/sys/block/$(basename ${device})boot0/force_ro"
	echo 1 > "/sys/block/$(basename ${device})boot1/force_ro"
}


install_bootloader "$1" "$2"

