#!/bin/sh


error() {
	echo $@
	exit 1
}

gpt_warning() {
	echo "GPT partition scheme already exists."
	read -p "Do you want to destroy it and create new one? (y/n) ? " DESTROY_PS
	if [ x"$DESTROY_PS" != "xy" ]; then
		return 1
	fi

	return 0
}

clear

device=""
for dev in /dev/mmcblk* ; do
	test -e "$dev" || continue
	device=${dev:5}
	test -e "/sys/class/block/${device}/device/type" || continue
	type="$(cat "/sys/class/block/${device}/device/type" 2>/dev/null)"
	name="$(cat "/sys/class/block/${device}/device/type" 2>/dev/null)"
	if [ "x$type" == "xMMC" ]; then
		device=$dev;
		break;
	fi
done


test -e "$device" || error "Device not found."

echo "$device ($type) [$name] will be repartitioned using GPT."
echo "What operating system(s) will you use ?"
echo " "
echo "1. Android 4 (Cyanogen Mod 11)"
echo "2. Android 4 (Cyanogen Mod 11) and Linux"
echo " "
read -p "Enter a number (or ctrl+c to exit): " OS_SELECTION

if [ x"$OS_SELECTION" != "1" ] && [ x"$OS_SELECTION" != "2" ]; then
	error Incorrect answer
fi

echo "Erasing partition scheme......"	
parted $device << EOF
unit s
mklabel gpt
EOF

config=""
case "$OS_SELECTION" in
	"1") config="cm11.cfg"
	"2") config="cm11_lnx.cfg"
	*) error "Unknow choise $OS_SELECTION"

esac

sh ./apply_partitions_config.sh "$config" $device || error Failed to switch to GPT

echo "Done."
