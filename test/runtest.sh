#!/bin/bash
# Compare STDIN with file specified as argument.

RED='\033[31m'
GREEN='\033[32m'
RESTORE='\033[0m'

#diff - $1
if [ "$1" = "-r" ]; then
	if `diff - $2 >/dev/null` ; then
		echo -e "$GREEN * TEST PASSED $RESTORE"
	else
		echo -e "$RED * TEST FAILED $RESTORE"
	fi
else
	cat /dev/stdin > $2

fi
