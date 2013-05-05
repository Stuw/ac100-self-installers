#!/bin/sh


apply_partitions_config()
{
	config_file="$1"
	
	cfg=$(cat $config_file)
	if [ -z "$cfg" ]; then
		echo "Config file $config_file was not found."
		return 1
	fi

	repart_cmd="unit s
	mklabel gpt"
	
	GPT_HDR=34
	first_free=$GPT_HDR
	
	i=1
	for rec in $cfg
	do
		if [[ "x#" == "x${rec:0:1}" ]]; then
			continue
		fi

		name="${rec%=*}"
		start_size="${rec#*=}"

		if [[ "$start_size" == *":"* ]]; then
			start="${start_size%:*}"
			size="${start_size#*:}"
		else
			start=$first_free
			size="${start_size}"
		fi

		if [ $size == "-1" ]; then
			size=$(( $disk_size - $GPT_HDR - $first_free ))
		fi
	
		end=$(( $start + $size ))
		first_free=$(( $end + 1 ))

		#echo "$name [$start:$end]"

		part_cmd="
mkpart primary $start $end
name $i $name"
	
		repart_cmd="${repart_cmd}${part_cmd}"
		i=$(( $i + 1 ))
	done 
	
	repart_cmd="${repart_cmd}
print
quit"
	
	device="/dev/mmcblk0"
	disk_size="$(blockdev --getsize ${device})"
	#device="image-8G.bin"
	#disk_size=$(( $(stat -c%s ${device}) / 512 ))
	echo "Disk size: $disk_size"
	if [ ! -e $device ]; then
		echo "Target device $device was not found"
		return 1
	fi
	
	echo $repart_cmd
	
	parted $device << EOF
$repart_cmd
EOF
	
}

error()
{
	echo $@
	exit 1
}

main()
{
	echo "Searching partition table..."
	sh ./dump_part_table.sh > current.cfg || error Failed to dump current partition table

	echo "Dumping boot partitions..."
	#sh ./boot_partitions.sh --dump || error Failed to dump boot partitions
	
	echo "Installing u-boot..."
	#sh ./install_bootloader.sh uboot.bin || error Failed to install u-boot

	echo "Switching to GPT..."	
	#apply_partitions_config current.cfg || error Failed to switch to GPT

	echo "Configuring u-boot..."
	#sh ./boot_partitions.sh --apply || error Failed to configure u-boot
	
	echo "Done."
}

main
