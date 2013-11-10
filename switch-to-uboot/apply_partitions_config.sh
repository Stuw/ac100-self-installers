#!/bin/sh


apply_partitions_config()
{
	config_file="$1"
	device="$2"
	
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

		echo $start_size | grep ":" > /dev/null
		if [[ $? == "0" ]]; then
			start="${start_size%:*}"
			size="${start_size#*:}"
		else
			start=$first_free
			size="${start_size}"
		fi

		if [ $size == "-1" ]; then
			size=$(( $disk_size - $GPT_HDR - $first_free ))
		fi
	
		end=$(( $start + $size - 1 ))
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


apply_partitions_config "$1" "$2"
