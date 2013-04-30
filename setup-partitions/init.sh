#!/bin/sh

config_file="$1.cfg"

GPT_HDR=34
repart_cmd="unit s
mklabel gpt"


main()
{
	i=1
	first_free=$GPT_HDR
	
	cfg=$(cat $config_file)
	if [ -z "$cfg" ]; then
		echo "Config file $config_file was not found."
		return 1
	fi

	for rec in $cfg
	do
		if [[ "x#" == "x${rec:0:1}" ]]; then
			echo "Skip $rec"
			continue
		fi

		name="${rec%=*}"
		size="${rec#*=}"
		if [ $size == "-1" ]; then
			size=$(( $disk_size - $GPT_HDR - $first_free ))
		fi
	
		start=$first_free
		end=$(( $start + $size ))
		first_free=$(( $end + 1 ))

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


main
