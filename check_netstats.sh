#!/bin/sh
#
#   Description: Plugin to collect infromation about TCP and UDP connections for Icinga2
#   Version: 1.0
#   Date: 2024.12.04
#
#   Author: Mayer Karoly (HA3MAK)
#   E-mail: mayer.karoly@sinuslink.hu
#   Web:    https://github.com/HA3MAK/monitoring-plugins
#
AWK=$(which awk 2>/dev/null)
export LC_NUMERIC=C

# Set some variables....
PLUGIN_OUTPUT_STATE=0
PLUGIN_OUTPUT_MSG="This plugin is only used for collect performance data!"
PLUGIN_OUTPUT_ADDITIONAL_MSG=""
STATE_NAMES="ESTABLISHED|SYN_SENT|SYN_RECV|FIN_WAIT1|FIN_WAIT2|TIME_WAIT|CLOSE|CLOSE_WAIT|LAST_ACK|LISTEN|CLOSING"
TRESHOLDS=""

# Check if awk is installed
if [ -z "${AWK}" ]
then
	# We can't work without awk
	echo "ERROR: awk was not found!"
	exit 3
fi

# Define some functions....

# This function just shows help
usage() {
	script_name=$(basename ${0})
	echo "Usage: ${script_name} [--treshold PROTOCOL:[CONNECTION STATE]:WARNING:CRITICAL]"
	echo ""
	echo "  This Icinga plugin checks TCP, UDP and ICMP connection counts."
    echo ""
	echo ""
	echo "Options:"
	echo "  --treshold, -t   Sets \"warning\" and \"critical\" treshold for selected metrics."
	echo "                   Can be used many times."
	echo "                   PROTOCOL can be: TCP, TCP6, UDP, UDP6, ICMP, ICMP6"
	echo "                   STATE(only with TCP or TCP6:): TOTAL|${STATE_NAMES}"
	echo ""
	echo "  --help, -h       Shows this help."
	echo ""
	echo ""
	echo "Usage example:"
	echo ""
	echo "In case of ESTABLISHED TCP connections on IPv4 and IPv6:"
	echo ""
	echo "  ${script_name} --treshold TCP:ESTABLISHED:10:20 --treshold TCP6:ESTABLISHED:10:20"
	echo ""
}

# Change plugin output state with given argument. Plugin state can be set to higher value but never to lower one.
set_output_state() {
	state=$1

	# Is the argument a valid integer?
	echo ${state} | grep -qE "^[0-9]+$"
	if [ $? -eq 0 ]
	then
		# Is the current given state bigger then the current?
		if [ ${state} -gt ${PLUGIN_OUTPUT_STATE} ]
		then
			# Do the state change
			PLUGIN_OUTPUT_STATE=${state}
		fi
	fi
}

# Do the treshold checks
check_tresholds() {
	proto=$1
	state=$2
	warning=$3
	critical=$4

	msg_text="${proto}"
	case ${proto} in
		"TCP")
			value=$(echo "${CONN_TCP_V4}" | grep -E "^${state}=[0-9]+$" | grep -Eo "[0-9]+$")
			msg_text="${proto} ${state}"
		;;
		"TCP6")
			value=$(echo "${CONN_TCP_V6}" | grep -E "^${state}=[0-9]+$" | grep -Eo "[0-9]+$")
			msg_text="${proto} ${state}"
		;;
		"UDP")
			value="${CONN_UDP_V4}"
		;;
		"UDP6")
			value="${CONN_UDP_V6}"
		;;
		"ICMP")
			value="${CONN_ICMP_V4}"
		;;
		"ICMP6")
			value="${CONN_ICMP_V6}"
		;;
	esac

	# If the current value is greater or equals then CRITICAL treshold....
	if [ ${value} -ge ${critical} ]
	then
		# Add the current critical alert to the plugin output....
		PLUGIN_OUTPUT_ADDITIONAL_MSG="${PLUGIN_OUTPUT_ADDITIONAL_MSG}\nCRITICAL: ${value} ${msg_text} connections (W: ${warning} C: ${critical})"
		# Set CRTICAL exit code
		set_output_state 2
	else
		# If the current value is greater or equals then WARNING treshold....
		if [ ${value} -ge ${warning} ]
		then
			# Add the current warning alert to the plugin output....
			PLUGIN_OUTPUT_ADDITIONAL_MSG="${PLUGIN_OUTPUT_ADDITIONAL_MSG}\nWARNING: ${value} ${msg_text} connections (W: ${warning} C: ${critical})"
			# Set WARNING exit code
			set_output_state 1
		else
			# We reached "OK"
			#PLUGIN_OUTPUT_ADDITIONAL_MSG="${PLUGIN_OUTPUT_ADDITIONAL_MSG}\nOK: ${value} ${msg_text} connections (W: ${warning} C: ${critical})"
			# This is just for change "This plugin is only used for collect performance data!" text....
			PLUGIN_OUTPUT_MSG="OK: Every values are below tresholds!"
			# Set OK exit code
			set_output_state 0
		fi
	fi
}


# End of functions.....


# Parse commandline arguments
while [ -n "${1}" ]
do

	case "${1}" in
		# Set alert treshold
		-t|--treshold)

			# Validate user input. It must have a strict format: TCP:ESTABLISHED:10:20, UDP:10:20 or ICMP:10:30
			echo "${2}" | grep -qE "(^(TCP|TCP6):(TOTAL|${STATE_NAMES}):[0-9]+:[0-9]+$|^(UDP|UDP6|ICMP|ICMP6):[0-9]+:[0-9]+$)"
			if [ $? -eq 0 ]
			then
				# User input is valid

				# Treshold protocol (TCP, TCP6, UDP, UDP6, ICMP, ICMP6)
				th_proto=$(echo "${2}" | ${AWK} -F ':' '{print $1}')
				# Connection state. Only valid for TCP or TCP6. I write "x" in every other cases...
				th_state=$(echo "${2}" | ${AWK} -F ':' '{if ($1 ~ /^TCP6?$/) {print $2;} else { print "x";}}')
				# If it's a TCP connection then warning treshold is in the 3rd field
				th_warning=$(echo "${2}" | ${AWK} -F ':' '{if ($1 ~ /^TCP6?$/) {print $3;} else { print $2;}}')
				# If it's a TCP connection then critical treshold is in the 4th field
				th_critical=$(echo "${2}" | ${AWK} -F ':' '{if ($1 ~ /^TCP6?$/) {print $4;} else { print $3;}}')

				# Add treshold values to the list....
				TRESHOLDS="${TRESHOLDS}${th_proto} ${th_state} ${th_warning} ${th_critical}\n"

			else
				# The argument of treshold was in invalid format
				echo "UNKNOWN - Invalid argument for treshold!"
				echo "${2}"
				exit 3				
			fi

			shift
		;;
		-h|--help)
			# Print help and exit....
			usage
			exit 3
		;;
		*)
			# We got an invalid argument
			echo "ERROR: Invalid argument: ${1}"
			echo "Run ./${0} --help for usage!"
			exit 3
		;;
	esac
	shift
done

# We are ready to do the job...



# Let's start with collecting data
# Get information about IPv4 TCP connections
CONN_TCP_V4=$(${AWK} -v st_names="${STATE_NAMES}" 'BEGIN {for(i=0; i<=15; ++i) { hex2dec[sprintf("%02x", i)] = i;}; n=split(st_names,states,"|");for (i=1;i<=n;i++) { states_sum[i]=0}; all_tcp=0;} $1 ~ /^[[:space:]]*[0-9]*:$/ {idx = hex2dec[tolower($4)]; states_sum[idx]++; all_tcp++;} END {print "TOTAL="all_tcp; for (i=1;i<=n;i++) { print states[i]"="states_sum[i]};}' /proc/net/tcp)
# Get information about IPv6 TCP connections
CONN_TCP_V6=$(${AWK} -v st_names="${STATE_NAMES}" 'BEGIN {for(i=0; i<=15; ++i) { hex2dec[sprintf("%02x", i)] = i;}; n=split(st_names,states,"|");for (i=1;i<=n;i++) { states_sum[i]=0}; all_tcp=0;} $1 ~ /^[[:space:]]*[0-9]*:$/ {idx = hex2dec[tolower($4)]; states_sum[idx]++; all_tcp++;} END {print "TOTAL="all_tcp; for (i=1;i<=n;i++) { print states[i]"="states_sum[i]};}' /proc/net/tcp6)
# Get number of total connections for UDP and ICMP. Cheaper to use grep for this....
CONN_UDP_V4=$(grep -c "^[[:space:]]*[0-9]*:" /proc/net/udp)
CONN_UDP_V6=$(grep -c "^[[:space:]]*[0-9]*:" /proc/net/udp6)
CONN_ICMP_V4=$(grep -c "^[[:space:]]*[0-9]*:" /proc/net/icmp)
CONN_ICMP_V6=$(grep -c "^[[:space:]]*[0-9]*:" /proc/net/icmp6)

# Format strings for perfdata
TCP_PERFDATA=$(echo "${CONN_TCP_V4}\nxxx\n${CONN_TCP_V6}" | ${AWK} 'BEGIN{suffix="4";} {if ($0=="xxx") {suffix="6";} else {split(tolower($0),fields,"="); printf "\047tcp"suffix"_"fields[1]"\047="fields[2]" ";}}')
UDP_PERFDATA="'udp4'=${CONN_UDP_V4} 'udp6'=${CONN_UDP_V6} "
ICMP_PERFDATA="'icmp4'=${CONN_ICMP_V4} 'icmp6'=${CONN_ICMP_V6} "
# Our performance datas are ready...
PLUGIN_PERFDATA="${TCP_PERFDATA}${UDP_PERFDATA}${ICMP_PERFDATA}"

#######

TH_COUNT=$(echo ${TRESHOLDS} | grep -Ec "^(TCP|UDP|ICMP)")
for i in $(seq 1 ${TH_COUNT})
do
	th=$(echo "${TRESHOLDS}" | head -n ${i} | tail -n -1)
	check_tresholds ${th}
done



# Set our exit message.
# If there were no tresholds set then exit with "This plugin is only used for collect performance data!"
# If there was minimum one treshold set and it was not violated then exit with "OK: Every values are below tresholds!"
# In other cases we set the exit message here....
case ${PLUGIN_OUTPUT_STATE} in
	1)
		PLUGIN_OUTPUT_MSG="WARNING: One or more value has reached the warning treshold!"
	;;
	2)
		PLUGIN_OUTPUT_MSG="CRITICAL: One or more value has reached the critical treshold!"
	;;
esac

# Write out information well formatted and exit
echo "${PLUGIN_OUTPUT_MSG}|${PLUGIN_PERFDATA}"
echo "${PLUGIN_OUTPUT_ADDITIONAL_MSG}"
exit ${PLUGIN_OUTPUT_STATE}

