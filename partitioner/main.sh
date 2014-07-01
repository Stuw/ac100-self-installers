#!/bin/sh


error() {
	echo $@
	exit 1
}

check_gpt() {
	PS="$(parted "$1" unit s print | grep "Partition Table" | awk -F ": " '{print $2}')"
	if [ "x$PS" == "xGPT" ]; then
		return 0
	fi

	return 1
}

show_no_gpt_warning() {
	echo "GPT partition scheme not found. Probably u-boot is not installed"
	echo "on this machine as a bootloader. To use GPT partition scheme you"
	echo "need to install u-boot first."
	echo "To install u-boot say n and run ./switch-to-uboot"
	echo " "
	read -p "Do you want to use GPT anyway? (y/n) ? " DESTROY_PS
	if [ x"$DESTROY_PS" != "xy" ]; then
		return 1
	fi

	echo " "
	return 0
}

clear

device=""
for dev in /dev/mmcblk* ; do
	test -e "$dev" || continue
	device=${dev:5}
	test -e "/sys/class/block/${device}/device/type" || continue
	type="$(cat "/sys/class/block/${device}/device/type" 2>/dev/null)"
	name="$(cat "/sys/class/block/${device}/device/name" 2>/dev/null)"
	if [ "x$type" == "xMMC" ]; then
		device=$dev;
		break;
	fi
done


test -e "$device" || error "Device not found."

check_gpt "$device" || show_no_gpt_warning || exit 1

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
