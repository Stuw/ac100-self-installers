#!/bin/sh

echo "$(date): $0 $@" >> /tmp/test.log
echo "$(date): $0 $@"

if [ -z "$2" ]; then
	exit 1
else
	exit 0
fi
