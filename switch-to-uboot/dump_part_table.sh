#!/bin/sh 
#
# This script tries to read out a NVIDIA partiton table found
# one some tegra device and convert it to a GPT type partition table.
# Ideally, this should be done without loosing data...
# Please report bugs on freenode #ac100

IGNORE="BCT PT EBT MBR EM1 EM2"
SCANDEVS="/dev/mmcblk*"
SKIP_HEADER=72
ENTRY_SIZE=$((20*4))
MAX_ENTRIES=13
PT_SIZE=$(($MAX_ENTRIES*$ENTRY_SIZE))
BPS=2048
IFS=" "

# find the size of the two secure partitions (ac100 only?)
secpart_size=$(/sbin/blockdev --getsz /dev/mmcblk?boot0)
secpart_size=$(( $secpart_size*2 ))
#secpart_size=$(( 2 * 1024 * 1024 / 512 ))

echo "trying to find NV PT ..." >&2

for dev in $SCANDEVS; do
    test -e $dev || continue
    pt=`dd if=$dev bs=2k count=1 skip=512 status=none| od -j$SKIP_HEADER -w$ENTRY_SIZE -N$PT_SIZE -tuz`
    #pt=`dd if=$dev bs=2k count=1 | od -j$SKIP_HEADER -w$ENTRY_SIZE -N$PT_SIZE -tuz`
    echo "checking $dev" >&2
    #echo "$pt" | awk '{print $2}'
    name=`echo "$pt" | head -n1 | awk '{print $22}' | sed -e "s/^>\.*\(\w\+\).*/\1/g"`
    #name=`echo "${PT[21]}" | sed -e "s/^>\.*\(\w\+\).*/\1/g"`
    if [ "x$name" == "xBCT" ]; then break; fi
done

if [ "x$name" != "xBCT" ]; then
    echo "no partition table found" >&2
    exit 1
fi

echo "found NV PT on $dev" >&2

dev=${dev:0:12}

echo "#Generated_by_script_from_device_'${dev}'"

i=1

while true
do
    rec=`echo "$pt" | head -n$i | tail -n1`
    name=`echo "$rec" | awk '{print $22}' | sed -e "s/^>\.*\(\w\+\).*/\1/g"`
    if [[ -z $name ]]; then
    	break
    fi
    
    i=$(( $i + 1 ))
    
    skip=0
    for ign in $IGNORE; do
        if [ "$ign" == "$name" -o "x" == "x$name" ]; then skip=1; fi
    done
    if [ "$skip" == "1" ]; then continue; fi
    
    start=$(( `echo "$rec" | awk '{print $12}'` * $BPS / 512 - $secpart_size ))
    size=$(( `echo "$rec" | awk '{print $14}'` * $BPS / 512 ))
    end=$(( $start + $size - 1 ))

    echo "${name}=${start}:${size}"
    #echo "$i: ${name} [${start}, ${end}] (size ${size})" >&2
done

