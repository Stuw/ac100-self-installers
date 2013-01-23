#!/bin/bash

CROSS_COMPILER=arm-linux-gnueabihf-
EXTERNALS="./externals"
mkdir -p "$EXTERNALS"

log_file="${1:-${EXTERNALS}/init-externals.log}"
log_file=$(readlink -f "${log_file}")
touch "${log_file}"

RES=0

function set_error() {
	RES=1
}

function msg() {
	echo $@ | tee -a "$log_file"
}

# nvflash
makeself_url="http://megastep.org/makeself/makeself.run"
#if [[ ! -e "${EXTERNALS}/makeself.run" ]]; then
	msg "Downloading makeself..."
	wget "$makeself_url" -P "$EXTERNALS" >> "${log_file}" 2>&1 || set_error
	chmod a+x "${EXTERNALS}/makeself.run" || set_error
	"${EXTERNALS}/makeself.run" --target "${EXTERNALS}/makeself"
	msg "Done."
#fi

pushd "$EXTERNALS" >> /dev/null


# EXTERNALS
popd >> /dev/null

exit $RES
