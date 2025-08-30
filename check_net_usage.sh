#!/bin/sh
#
#   Description: Network interface usage information collector plugin for Icinga2
#   Version: 1.0
#   Date: 2025.08.30
#
#   Author: Mayer Karoly (HA3MAK)
#   E-mail: mayer.karoly@sinuslink.hu
#   Web:    https://github.com/HA3MAK/monitoring-plugins
#
AWK=$(which awk 2>/dev/null)
BC=$(which bc 2>/dev/null)
export LC_NUMERIC=C

# Check if awk is installed
if [ -z "${AWK}" ]
then
	# We can't work without awk
	echo "ERROR: \"awk\" was not found!"
	exit 2
fi

# Check if bc is installed
if [ -z "${BC}" ]
then
	# We can't work without bc
	echo "ERROR: \"bc\" was not found!"
	exit 2
fi

# Who am I?
ID=$(id -u -n)

# Write statistics into our home
ICINGA_HOME=$(eval echo "~${ID}")
STATS_FILE="${ICINGA_HOME}/icinga2_network_traffic_statistics"

# Initialize PERFDATA variable
PERFDATA=""

# Get the current unix timestamp
CURRENT_CHECK_TIME=$(date +"%s")
# Read data from procfs
RAW_DATA=$(grep -E '^[[:space:]]*[a-zA-Z0-9]+:' /proc/net/dev)
# How many lines do we have?
DATA_LINES=$(echo "${RAW_DATA}" | wc -l)

# If there are no data lines then exit with error...
if [ ${DATA_LINES} -eq 0 ]
then
	echo "ERROR: No network interfaces were found!"
	# Exit with critical
	exit 2
fi

# Read last statistics from file
LAST_STATS=$(cat ${STATS_FILE} 2>/dev/null)
LAST_STATS_LINES=$(cat ${STATS_FILE} 2>/dev/null | wc -l)
# Empty the statistics file
echo -n > ${STATS_FILE}

# Let's check the interface statistics....
for i in $(seq 1 ${DATA_LINES})
do
	# Get one line of data
	line=$(echo "${RAW_DATA}" | head -n ${i} | tail -n 1)

	# The name of the current interface
	interface=$(echo "${line}" | ${AWK} '{gsub(/:/,"",$1);print $1}')
	# Get byte counters of current interface
	current_bytes_rx=$(echo "${line}" | ${AWK} '{print $2}')
	current_bytes_tx=$(echo "${line}" | ${AWK} '{print $10}')

	# Write current data into statistics file
	echo "${CURRENT_CHECK_TIME} ${interface} ${current_bytes_rx} ${current_bytes_tx}" >> ${STATS_FILE}

	# If it's our first run don't try to calculate...
	if [ ${LAST_STATS_LINES} -gt 0 ]
	then

		# Read data from the last check
		last_check_time=$(echo "${LAST_STATS}" | ${AWK} -v net_if=${interface} '{if ($2==net_if) {print $1}}')
		last_bytes_rx=$(echo "${LAST_STATS}" | ${AWK} -v net_if=${interface} '{if ($2==net_if) {print $3}}')
		last_bytes_tx=$(echo "${LAST_STATS}" | ${AWK} -v net_if=${interface} '{if ($2==net_if) {print $4}}')

		# Calculate time between checks
		check_time=$(echo "${CURRENT_CHECK_TIME}-${last_check_time}" | ${BC})
		# Calculate received bytes since the last check
		bytes_rx=$(echo "${current_bytes_rx}-${last_bytes_rx}" | ${BC})
		# Calculate transmitted bytes since the last check
		bytes_tx=$(echo "${current_bytes_tx}-${last_bytes_tx}" | ${BC})

		# Calculate average speed since the last check
		speed_rx=$(echo "scale=0;(${bytes_rx}/${check_time})*8" | ${BC} -l) # bits/s
		speed_tx=$(echo "scale=0;(${bytes_rx}/${check_time})*8" | ${BC} -l) # bits/s

		# Write perfdata of interface into the PERFDATA variable
		PERFDATA="${PERFDATA}'${interface}_rx'=${speed_rx}bps '${interface}_tx'=${speed_tx}bps "
	fi

done

# Print perfdata and exit with ok
echo "This plugin is only used for collect performance data!| ${PERFDATA}"
exit 0

