#!/bin/sh
#
#   Description: Linux memory usage information collector plugin for Icinga2
#   Version: 1.0
#   Date: 2024.11.23
#
#   Author: Mayer Karoly (HA3MAK)
#   E-mail: mayer.karoly@sinuslink.hu
#   Web:    https://github.com/HA3MAK/monitoring-plugins
#
AWK=$(which awk 2>/dev/null)
export LC_NUMERIC=C

if [ -z "${AWK}" ]
then
	echo "ERROR: \"awk\" was not found!"
	exit 2
fi

check_error() {

	if [ $1 -ne 0 ]
	then
		echo "ERROR: Something went wrong! :("
		exit 2
	fi
}

MEM_TOTAL=$(${AWK} -F ':' '$1 ~ /^MemTotal$/ {split($2,val," ");print val[1]}' /proc/meminfo 2>/dev/null)
check_error $?
MEM_AVAILABLE=$(${AWK} -F ':' '$1 ~ /^MemAvailable$/ {split($2,val," ");print val[1]}' /proc/meminfo 2>/dev/null)
check_error $?
MEM_CACHED=$(${AWK} -F ':' 'BEGIN { buffers=cached=0; } $1 ~ /^Buffers$|^Cached$/ {	if ($1=="Buffers") {split($2,val," ");buffers=val[1];};	if ($1=="Cached") {split($2,val," "); cached=val[1];}; } END {print (buffers+cached);}' /proc/meminfo 2>/dev/null)
check_error $?

MEM_SHARED_TOTAL=$(${AWK} -v mem_total=${MEM_TOTAL} '{shmmax=$0/1024; if (shmmax<mem_total) {print shmmax;} else {print mem_total;}}' /proc/sys/kernel/shmmax 2>/dev/null)
check_error $?
MEM_SHARED_USED=$(${AWK} -F ':' '$1 ~ /^Shmem$/ {split($2,val," ");print val[1]}' /proc/meminfo 2>/dev/null)
check_error $?

echo "This plugin is only used for collect performance data!|'mem_total'=${MEM_TOTAL}kB 'mem_free'=${MEM_AVAILABLE}kB 'mem_cached'=${MEM_CACHED}kB 'mem_shared_total'=${MEM_SHARED_TOTAL}kB 'mem_shared_used'=${MEM_SHARED_USED}kB"
exit 0

