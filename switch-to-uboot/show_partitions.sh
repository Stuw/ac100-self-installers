#!/bin/sh


show_partitions()
{
	config_file="$1"
	
	cfg=$(cat $config_file)
	if [ -z "$cfg" ]; then
		echo "Config file $config_file was not found."
		return 1
	fi

	GPT_HDR=34
	first_free=$GPT_HDR
	
	i=1
	for rec in $cfg
	do
		if [[ "x#" == "x${rec:0:1}" ]]; then
			continue
		fi

		name_fs="${rec%=*}"
		start_size="${rec#*=}"

		echo $name_fs | grep ":" > /dev/null
		if [[ $? == "0" ]]; then
			name="${name_fs%:*}"
			fs="${name_fs#*:}"
		else
			name="${name_fs}"
			fs=""
		fi

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

		echo "$name [start:$start, end:$end, fs: $fs]"
		
		i=$(( $i + 1 ))
	done 
	
}

show_partitions "$1"
