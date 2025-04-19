#!/bin/sh
#
#   Description: Plugin for Icinga2 to alert when the host rebooted
#   Version: 1.0
#   Date: 2025.04.19
#
#   Author: Mayer Karoly (HA3MAK)
#   E-mail: mayer.karoly@sinuslink.hu
#   Web:    https://github.com/HA3MAK/monitoring-plugins
#
#Set some variables
ID=$(id -u -n)
HOMEDIR=$(eval echo "~${ID}")
UPTIME_FILE="${HOMEDIR}/uptime.stat"
CURRENT_UPTIME=$(grep -o "^[0-9]*" /proc/uptime)

#Show help
usage() {
	script_name=$(basename ${0})
	echo "Usage: ${script_name} [--help]"
	echo ""
	echo "  This Icinga plugin alerts when host restarted."
    echo ""
	echo ""
	echo "Options:"
	echo "  -c               Returns \"CRITICAL\" without checking actual state."
	echo "  --help, -h       Shows this help."
	echo ""
	echo ""
	echo "Use the following Icinga2 Service definition for this plugin. This way the check will stay \"critical\" "
	echo "until you set it to \"ok\" state manually."
	echo ""
	echo "    apply Service \"Uptime\" {"
	echo "      import \"generic-service\""
	echo "      command_endpoint = host.vars.client_endpoint"
	echo ""
	echo "      check_command = \"custom_uptime\""
	echo ""
	echo "      var that = this"
	echo "      vars.uptime_state = function() use(that) {"
	echo "        return if (that.last_check_result && that.last_check_result.state == 2) { that.last_check_result.state } else { \"\" }"
	echo "      }"
	echo ""
	echo "      assign where [...]"
	echo "    }"
	echo ""
}

uptime_check() {

	#Check if the "uptime.stats" file exists
	if [ -f "${UPTIME_FILE}" ]
	then
		#File exists.. Read uptime
		LAST_UPTIME=$(cat ${UPTIME_FILE})
		#If current uptime is less than what we found in the file....
		if [ "${CURRENT_UPTIME}" -lt "${LAST_UPTIME}" ]
		then
			#Reboot happened... Return critical...
			return 2
		fi

	fi

	return 0
}

uptime_update() {
	#Write current uptime
	echo ${CURRENT_UPTIME} > ${UPTIME_FILE}
}

calculate_uptime() {
	uptime=$1

	#Check if uptime is a number
	echo "${uptime}" | grep -q "[0-9]*"

	if [ $? -eq 0 ]
	then

		
		seconds=${uptime}
		minutes=0
		hours=0
		days=0

		#Output only in seconds
		output="${seconds} seconds"

		if [ "${uptime}" -ge 60 ]
		then
			#Uptime is greater than 60 seconds so output in minutes and seconds
			minutes=$((${uptime}/60))
			seconds=$((${seconds}-${minutes}*60))

			output="${minutes} minutes and ${seconds} seconds"

			if [ "${minutes}" -ge 60 ]
			then
				#Output should contain hours too
				hours=$((${uptime}/60/60))
				minutes=$((${minutes}-${hours}*60))

				output="${hours} hours, ${minutes} minutes and ${seconds} seconds"

				if [ "${hours}" -ge 24 ]
				then
					#Hours is greater than 24 so output contains days too
					days=$((${uptime}/60/60/24))
					hours=$((${hours}-${days}*24))

					output="${days} days, ${hours} hours, ${minutes} minutes and ${seconds} seconds"
				fi
			fi
		fi

		#Print the well formatted uptime
		echo "Last boot was ${output} ago"

	fi


}

exit_ok() {
		#There was no reboot since the last check
		up_since=$(calculate_uptime ${CURRENT_UPTIME})
		echo "OK - ${up_since}"
		exit 0
}

exit_critical() {
		#There was a reboot
		echo "CRITICAL - Host restarted!"
		exit 2
}

#The only command line argument we accept is "-h" and "--help"
if [ ! -z "${1}" ]
then
	case "${1}" in
		--help|-h)
			#Print help and exit
			usage
			exit 0
		;;
		-c)
			#Don't do anything just exit with critical
			exit_critical
		;;
		*)
			#Invalid argument was found. Exit with code of unknown state
			echo "UNKNOWN - Invalid argument"
			exit 3
		;;
	esac
fi

#Let's do the work.. Check if there was a reboot or not
uptime_check
EXIT_CODE=$?
#Write current uptime
uptime_update


case "${EXIT_CODE}" in
	0)
		#There was no reboot since the last check
		exit_ok
	;;
	2)
		#There was a reboot
		exit_critical
	;;
esac

#Never should reach this point
echo "UNKNOWN - Something unexpected happened! :("
exit 3

