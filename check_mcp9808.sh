#!/bin/sh
#
#   Description: Plugin for MCP9808 I2C temperature sensor
#   Version: 1.0
#   Date: 2025.10.18
#
#   Author: Mayer Karoly (HA3MAK)
#   E-mail: mayer.karoly@sinuslink.hu
#   Web:    https://github.com/HA3MAK/monitoring-plugins
#
#   TODO: warning and critical tresholds could be intervals in form "<min>:<max>"
I2CGET=$(which i2cget 2>/dev/null)
AWK=$(which gawk 2>/dev/null)

# Set default I2C bus device and chip address
I2C_BUS="1"
I2C_ADDRESS="0x18"
WARNING=""
CRITICAL=""

# This function just shows help
usage() {
	script_name=$(basename ${0})
	echo "Usage: ${script_name} [--warning <integer>] [--critical <integer>]"
	echo ""
	echo "  This Icinga plugin checks for MCP9808 I2C temperature sensor"
    echo ""
	echo ""
	echo "Options:"
	echo "  --bus, -b        I2C bus address. Can be integer or device path."
	echo "                   (Default: ${I2C_BUS})"
	echo "  --address, -a    I2C chip address in hexadecimal form."
	echo "                   (Default: ${I2C_ADDRESS})"
	echo "  --warning, -w    Sets \"warning\" treshold for temperature"
	echo "  --critical, -c   Sets \"critical\" treshold for temperature"
	echo "  --help, -h       Shows this help."
	echo ""
	echo ""
}

# Checking dependencies....
if [ -z ${I2CGET} ]
then
	echo "UNKNOWN - i2cget was not found! "
	exit 3
fi

if [ -z ${AWK} ]
then
	echo "UNKNOWN - gawk was not found! "
	exit 3
fi

# Parse arguments
while [ -n "${1}" ]
do
	case "${1}" in
		-b|--bus)
			# The value of argument must be an integer or path to an existing character device
			echo "${2}" | grep -qE "^[0-9]+$"
			if [ $? -eq 0 ] || [ -c "${2}" ]
			then
				# Argument is integer
				I2C_BUS="${2}"
			else
				# Argument must be an integer....
				echo "UNKNOWN - Invalid I2C bus address. Must be integer or device path."
				exit 3
			fi
			shift
		;;
		-a|--address)
			# The value of argument must be a hexadecimal integer
			echo "${2}" | grep -qE "^0x[0-9]+$"
			if [ $? -eq 0 ]
			then
				# Argument is integer
				I2C_ADDRESS="${2}"
			else
				# Argument must be an integer....
				echo "UNKNOWN - I2C chip address is invalid. Must be a hexadecimal address."
				exit 3
			fi
			shift
		;;
		-w|--warning)
			# The value of argument must be an integer
			echo "${2}" | grep -qE "^[0-9]+$"
			if [ $? -eq 0 ]
			then
				# Argument is integer
				WARNING="${2}"
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
				CRITICAL="${2}"
			else
				# Argument must be an integer....
				echo "UNKNOWN - Warning threshold must be an integer!"
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


# Warning argument is mandatory and must be an integer
echo "${WARNING}" | grep -qE "^[0-9]+$"
if [ $? -ne 0 ]
then
	echo "UNKNOWN - warning treshold must be given and must be an integer!"
	exit 3
fi

# Critical argument is mandatory and must be an integer
echo "${CRITICAL}" | grep -qE "^[0-9]+$"
if [ $? -ne 0 ]
then
	echo "UNKNOWN - critical treshold must be given and must be an integer!"
	exit 3
fi

# Warning must be less than critical
if [ ${WARNING} -ge ${CRITICAL} ]
then
	echo "UNKNOWN - Warning treshold can't be greater or equal to critical treshold!"
	exit 3
fi

# Datasheet: https://ww1.microchip.com/downloads/en/DeviceDoc/25095A.pdf
# Make sure it's an MCP9808...
DEVICE_ID=$(${I2CGET} -y ${I2C_BUS} ${I2C_ADDRESS} 0x07 w 2>/dev/null)
if [ "${DEVICE_ID}" != "0x0004" ]
then
	echo "UNKNOWN - Not an MCP9808 temperature sensor!"
	exit 3
fi



# Read temperature data from MCP9808 on I2C
RAW_DATA=$(${I2CGET} -y ${I2C_BUS} ${I2C_ADDRESS} 0x05 i 2 2>/dev/null)
if [ $? -ne 0 ]
then
	echo "CRITICAL - Error while reading I2C data!"
	exit 2
fi

# Let's awk do the dirty job (See MCP9808 datasheet)
TEMP=$(echo "${RAW_DATA}" | ${AWK} '{
    raw = or(lshift(strtonum($1), 8), strtonum($2))
	tempC = and(raw, 0x0FFF)
	tempC /= 16

	if (and(raw, 0x1000)) {
		tempC -= 256
	}

	printf "%.1f\n", tempC
}')
# Remove decimal digits
TEMP_INT=$(echo "${TEMP}" | grep -Eo "^[0-9]+")


MESSAGE="Temperature is ${TEMP} °C"
PERFDATA="'temperature'=${TEMP}°C"

# Temperature value is greater than critical treshold?
if [ ${TEMP_INT} -ge ${CRITICAL} ]
then
	echo "CRITICAL - ${MESSAGE}|${PERFDATA}"
	exit 2
else
	# Temperature value is greater than warning treshold?
	if [ ${TEMP_INT} -ge ${WARNING} ]
	then
		echo "WARNING - ${MESSAGE}|${PERFDATA}"
		exit 1
	else
		# Temperature value is ok
		echo "OK - ${MESSAGE}|${PERFDATA}"
		exit 0
	fi
fi

# Have no clue what went wrong....
echo "UNKNOWN - Something unexpected happened! :("
exit 3
