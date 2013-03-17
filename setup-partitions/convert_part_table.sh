#!/bin/bash 
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

echo "trying to find NV PT ..."

for dev in $SCANDEVS; do
    test -e $dev || continue
    pt=`dd if=$dev bs=2k count=1 skip=512 status=none| od -j$SKIP_HEADER -w$ENTRY_SIZE -N$PT_SIZE -tuz`
    echo "checking $dev"
    read -a PT <<< "$pt"
    name=`echo "${PT[21]}" | sed -e "s/^>\.*\(\w\+\).*/\1/g"`
    if [ "x$name" == "xBCT" ]; then break; fi
done

if [ "x$name" != "xBCT" ]; then
    echo "no partition table found"
    exit 1
fi

echo "found NV PT on $dev"

dev=${dev:0:12}

read -p "Continue (y/n) ? "
if [ x"$REPLY" != "xy" ]; then
    exit
fi

echo -n "doing backup"
dd if=$dev of=nvpart-backup.img bs=4k count=1
echo ", ok"

echo "create gpt partition on $dev"

PARTED_CMD="unit s
mklabel gpt
"
i=1

while read -a PT
do
    name=`echo "${PT[21]}" | sed -e "s/^>\.*\(\w\+\).*/\1/g"`
    skip=0
    for ign in $IGNORE; do
        if [ "$ign" == "$name" -o "x" == "x$name" ]; then skip=1; fi
    done
    if [ "$skip" == "1" ]; then continue; fi
    start=$(( ${PT[11]}*$BPS/512-$secpart_size ))
    size=$(( ${PT[13]}*$BPS/512 ))
#    echo "$name: start=$start size=$size"
#    echo "$name=$size"
    end=$(( $start + $size - 1 ))
    TMP="mkpart primary ext2 $start $end
name $i $name
"
    PARTED_CMD="${PARTED_CMD}$TMP"
    i=$(( $i + 1 ))
done <<< "$pt"

PARTED_CMD="$PARTED_CMD
print
quit
"

#echo $PARTED_CMD
#echo $pt

parted -a none $dev << EOF
$PARTED_CMD
EOF

partprobe -s
