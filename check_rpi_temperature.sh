#!/bin/sh
#
#   Description: Plugin for Raspberry Pi SoC temperature check
#   Version: 1.0
#   Date: 2025.10.18
#
#   Author: Mayer Karoly (HA3MAK)
#   E-mail: mayer.karoly@sinuslink.hu
#   Web:    https://github.com/HA3MAK/monitoring-plugins
#

BC=$(which bc 2>/dev/null)
export LC_NUMERIC=C

# Dependency check
if [ -z "${BC}" ]
then
	echo "ERROR: \"bc\" was not found!"
	exit 2
fi

# Set default tresholds
TRESHOLD_WARNING=68
TRESHOLD_CRITICAL=78


# This function just shows help
usage() {
	script_name=$(basename ${0})
	echo "Usage: ${script_name} [--warning <integer>] [--critical <integer>]"
	echo ""
	echo "  This Icinga plugin checks for Raspberry Pi SoC temperature."
    echo ""
	echo ""
	echo "Options:"
	echo "  --warning, -w    Sets \"warning\" treshold for SoC temperature"
	echo "                   (Default value: ${TRESHOLD_WARNING})"
	echo "  --critical, -c   Sets \"critical\" treshold for SoC temperature"
	echo "                   (Default value: ${TRESHOLD_CRITICAL})"
	echo "  --help, -h       Shows this help."
	echo ""
	echo ""
}

# Parse arguments
while [ -n "${1}" ]
do
	case "${1}" in
		-w|--warning)
			# The value of argument must be an integer
			echo "${2}" | grep -qE "^[0-9]+$"
			if [ $? -eq 0 ]
			then
				# Argument is integer
				TRESHOLD_WARNING=${2}
			else
				# Argument must be an integer....
				echo "UNKNOWN - Warning threshold must be an integer!"
				exit 3
			fi
			shift
		;;
		-c|--critical)
			# The value of argument must be an integer
			echo "${2}" | grep -qE "^[0-9]+$"
			if [ $? -eq 0 ]
			then
				# Argument is integer
				TRESHOLD_CRITICAL=${2}
			else
				# Argument must be an integer....
				echo "UNKNOWN - Critical threshold must be an integer!"
				exit 3
			fi
			shift
		;;
		-h|--help)
			usage
			exit 0
		;;
		*)
			# Invalid argument was given
			echo "UNKNOWN - Invalid argument!"
			echo "${1}"
			exit 3
		;;
	esac
	shift
done

# Critical must be greater than warning
if [ ${TRESHOLD_WARNING} -ge ${TRESHOLD_CRITICAL} ]
then
	echo "UNKNOWN - Warning treshold can't be greater than or equal to critical treshold."
	exit 3
fi

# Check if are we running on a Raspberry Pi
grep -q "^Raspberry Pi" /sys/firmware/devicetree/base/model 2>/dev/null
if [ $? -eq 0 ]
then

	# Read temperature of SoC form sysfs
	TEMP_RAW=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
	if [ $? -ne 0 ]
	then
		# Somehow we can't read the remperature value :(
		echo "UNKNOWN - Error while reading temperature!"
		exit 3
	fi

	# Divide by 1000 to get celsius
	TEMP=$(echo "scale=1;${TEMP_RAW}/1000" | ${BC} -l)
	TEMP_INT=$(echo "${TEMP}" | grep -Eo "^[0-9]+")
	MESSAGE="SoC Temperature: ${TEMP} °C"
	PERFDATA="'temperature'=${TEMP}°C"

	# If temperature is greater than or equal to critical treshold
	if [ ${TEMP_INT} -ge ${TRESHOLD_CRITICAL} ]
	then
		echo "CRITICAL - ${MESSAGE}|${PERFDATA}"
		exit 2
	else
		# If temperature is greater than or equal to warning treshold
		if [ ${TEMP_INT} -ge ${TRESHOLD_WARNING} ]
		then
			echo "WARNING - ${MESSAGE}|${PERFDATA}"
			exit 1
		else
			# Everything is ok
			echo "OK - ${MESSAGE}|${PERFDATA}"
			exit 0
		fi
	fi

else
	# Not running on Raspberry Pi
	echo "UNKNOWN - This check must be running on Raspberry Pi!"
	exit 3
fi


# No clue what happened...
echo "UNKNOWN - Something unexpected happened! :("
exit 3

