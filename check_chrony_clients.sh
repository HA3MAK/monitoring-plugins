#!/bin/sh
#
#   Description: Chrony clients usage information collector plugin for Icinga2
#   Version: 1.1
#   Date: 2025.10.21
#
#   Author: Mayer Karoly (HA3MAK)
#   E-mail: mayer.karoly@sinuslink.hu
#   Web:    https://github.com/HA3MAK/monitoring-plugins
#
CHRONYC=$(which chronyc 2>/dev/null)
AWK=$(which awk 2>/dev/null)
SUDO=$(which sudo 2>/dev/null)

# Checking for dependencies....
if [ -z "${CHRONYC}" ]
then
	echo "UNKNOWN - \"chronyc\" was not found!"
	exit 3
fi

if [ -z "${AWK}" ]
then
	echo "UNKNOWN - \"awk\" was not found!"
	exit 3
fi

# Trying to get clients statistics
CHRONYC_OUT=$(${CHRONYC} -c clients 2>/dev/null)

if [ $? -ne 0 ]
then

	# Is sudo installed?
	if [ -z ${SUDO} ]
	then
		echo "UNKNOWN - \"sudo\" was not found! "
		exit 3
	fi

	# Trying to get clients statistics
	CHRONYC_OUT=$(${SUDO} ${CHRONYC} -c clients 2>/dev/null)

	if [ $? -ne 0 ]
	then
		ICINGA_USERNAME=$(id -un)
		# Failed to get statistics from chrony :(
		echo "UNKNOWN - Error while getting clients statistics from chrony!"
		echo "Maybe permission problem? You should add to sudoers this line:"
		echo
		echo "${ICINGA_USERNAME} ALL=(ALL) NOPASSWD: ${CHRONYC} -c clients"
		exit 3
	fi
fi


# Calculate perfdata for output
PERFDATA=$(echo "${CHRONYC_OUT}" | ${AWK} -F ',' '
BEGIN{
	hosts_num=0;
	ntp_packets=0;
	ntp_packets_drop=0;
	cmd_packets=0;
	cmd_packets_drop=0;
}

{

	# Count clients only which sent packet in the last hour
	if ( $6 < 3600 || $10 < 3600 ) {
		hosts_num++;
		ntp_packets+=$2;
		ntp_packets_drop+=$3;
		cmd_packets+=$7;
		cmd_packets_drop+=$8;
	}
}

END {
	printf "\047clients_num\047=" hosts_num " "
	printf "\047ntp_pkt\047=" ntp_packets " "
	printf "\047ntp_pkt_drop\047=" ntp_packets_drop " "
	printf "\047cmd_pkt\047=" cmd_packets " "
	printf "\047cmd_pkt_drop\047=" cmd_packets_drop " "

}')

if [ $? -eq 0 ]
then
	# Everything ok
	echo "This plugin is only used for collect performance data!|${PERFDATA}"
	exit 0
fi

# What happened!? :o
echo "UNKNOWN - Something unexpected happened! :("
exit 3


