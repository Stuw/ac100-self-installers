#!/bin/bash

IGNORE="BCT PT EBT LNX SOS MBR EM1 EM2"
SCANDEVS="/dev/mmcblk1 /dev/mmcblk1boot1"
SKIP_HEADER=72
ENTRY_SIZE=$((20*4))
MAX_ENTRIES=13
PT_SIZE=$(($MAX_ENTRIES*$ENTRY_SIZE))
BPS=2048
IFS=" "

secpart_size=$(/sbin/blockdev --getsz /dev/mmcblk1boot0)
secpart_size=$(( $secpart_size*2 ))

for dev in $SCANDEVS; do
	pt=`dd if=$dev bs=2k count=1 skip=512 status=none| od -j$SKIP_HEADER -w$ENTRY_SIZE -N$PT_SIZE -tuz`
#    echo "checking $dev"
	read -a PT <<< "$pt"
	name=`echo "${PT[21]}" | sed -e "s/^>\.*\(\w\+\).*/\1/g"`
	if [ "x$name" == "xBCT" ]; then break; fi
done

# echo "found PT on $dev"

pt=`dd if=$dev bs=2k count=1 skip=512 status=none | od -j$SKIP_HEADER -w$ENTRY_SIZE -N$PT_SIZE -tuz`

while read -a PT
do
	name=`echo "${PT[21]}" | sed -e "s/^>\.*\(\w\+\).*/\1/g"`
	skip=0
	for i in $IGNORE; do
		if [ "$i" == "$name" -o "x" == "x$name" ]; then skip=1; fi
	done
	if [ "$skip" == "1" ]; then continue; fi
	start=$(( ${PT[11]}*$BPS/512-$secpart_size ))
	size=$(( ${PT[13]}*$BPS/512 ))
	echo "$name: start=$start size=$size"
done <<< "$pt"

#echo $pt
