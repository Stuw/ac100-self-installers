#!/bin/sh

PARTED_LOG="/tmp/parted.log"

error()
{
	echo $@
	echo "For more information see $PARTED_LOG"
	exit 1
}

# 1 - dev
erase_partitions() {
	local dev="$1"
	local cmd="unit s"
	
	for p in $(parted -s "$dev" print | awk '/^ / {print $1}')
	do
		cmd="$cmd
rm $p"
	done
	
	parted $dev >>"$PARTED_LOG" 2>&1 << EOF
$cmd
quit
EOF
}


# 1 - config file
# 2 - device
apply_partitions_config()
{
	local config_file="$1"
	local device="$2"
	
	[ -z "$config_file" ] || error "Config file is not specified"
	[ -e "$config_file" ] || error "Config file $config_file doesn't exist"
	[ -z "$device" ] || error "Device is not specified"
	[ -e "$device" ] || error "Device $device doesn't exist"
	
	local format_cmd=""

	local repart_cmd="sgdisk --zap-all $device"
	
	local GPT_HDR=34
	local first_free=$GPT_HDR
	
	local i=1
	while read rec
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

		echo "$name [$start:$end] (fs: $fs)" >>"$PARTED_LOG"
		
		case "$fs" in
			"ext2")
				format_cmd="$format_cmd mkfs.$fs ${device}p$i && " ;;
			"ext3")
				format_cmd="$format_cmd mkfs.$fs ${device}p$i &&" ;;
			"ext4")
				format_cmd="$format_cmd mkfs.$fs ${device}p$i &&" ;;
			*)
			;;
		esac

		part_cmd="sgdisk -n ${1}:${start}:${end} -c ${1}:${name} $device"

		repart_cmd="${repart_cmd} && ${part_cmd}"

		i=$(( $i + 1 ))
	done < "$config_file"

	# Append tail command
	format_cmd="${format_cmd} true"	
	
	disk_size="$(blockdev --getsize ${device})"
	[ -z "$disk_size" ] && error "Can't detect disk size"
	#device="image-8G.bin"
	#disk_size=$(( $(stat -c%s ${device}) / 512 ))
	echo "Disk size: $disk_size" >>"$PARTED_LOG"
	if [ ! -e $device ]; then
		echo "Target device $device was not found"
		return 1
	fi
	
	echo $repart_cmd >>"$PARTED_LOG" 2>&1
	
	erase_partitions "$device" || error "Can't remove old partitions"
	
	echo "Repartitioning..." | tee -a "$PARTED_LOG"

	eval "$repart_cmd" >>"$PARTED_LOG" 2>&1
	if [[ $? != "0" ]]; then
		error "Repartition failed."
	fi

	# Force kernel to update partitions info
	partprobe -s >> "$PARTED_LOG" 2>&1
	sync

	# Formatting
	echo "Formatting..." | tee -a "$PARTED_LOG"
	local res=0
	if [ -z "$format_cmd" ]; then
		echo "Without formatting." >>"$PARTED_LOG" 2>&1
	else
		echo "$format_cmd" >>"$PARTED_LOG" 2>&1
		eval "$format_cmd" >>"$PARTED_LOG" 2>&1
		local err=$?
		[ $err -ne 0 ] && res=1
		echo -e "Result: $err (res: $res)\n" >>"$PARTED_LOG" 2>&1
	fi

	sgdisk -p $device >>"$PARTED_LOG" 2>&1
	
	return $res
}

apply_partitions_config "$1" "$2"
