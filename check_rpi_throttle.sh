#!/bin/sh
#
#   Description: Plugin for check Raspberry Pi CPU throttling
#   Version: 1.0
#   Date: 2025.10.18
#
#   Author: Mayer Karoly (HA3MAK)
#   E-mail: mayer.karoly@sinuslink.hu
#   Web:    https://github.com/HA3MAK/monitoring-plugins
#

VCGENCMD=$(which vcgencmd 2>/dev/null)
AWK=$(which gawk 2>/dev/null)
SUDO=$(which sudo 2>/dev/null)

# Dependency checks
if [ -z ${VCGENCMD} ]
then
	echo "ERROR: vcgencmd was not found! "
	exit 3
fi

if [ -z ${AWK} ]
then
	echo "ERROR: gawk was not found! "
	exit 3
fi

# We check for sudo only if we will use it...

# Try to run vcgencmd as a simple user
VCGENCMD_OUTPUT=$(${VCGENCMD} get_throttled)
if [ $? -ne 0 ]
then
	# We can't run vcgencmd as a simple user

	# Is sudo installed?
	if [ -z ${SUDO} ]
	then
		echo "ERROR: sudo was not found! "
		exit 3
	fi

	# Try with sudo
	VCGENCMD_OUTPUT=$(${SUDO} ${VCGENCMD} get_throttled 2>/dev/null)
	if [ $? -ne 0 ]
	then
		# Maybe a sudo rule is missing...
		ICINGA_USERNAME=$(id -un)
		echo "UNKNOWN - Error while running \"vcgencmd get_throttled\"!"
		echo "Maybe a sudo rule is missing? Example:"
		echo "${ICINGA_USERNAME} ALL=(ALL) NOPASSWD: ${VCGENCMD} get_throttled"
		exit 3
	fi
fi


# Everything is ok. Let awk do the decoding job and exit with the corresponding exit code
echo | ${AWK} -v vcgencmd_output="${VCGENCMD_OUTPUT}" '
BEGIN {
	bits_current[0x1] = "Undervoltage detected"
	bits_current[0x2] = "Arm frequency capped"
	bits_current[0x4] = "Currently throttled"
	bits_current[0x8] = "Soft temperature limit active"

	bits_sticky[0x10000] = "Undervoltage has occurred"
	bits_sticky[0x20000] = "Arm frequency capping has occurred"
	bits_sticky[0x40000] = "Throttling has occurred"
	bits_sticky[0x80000] = "Soft temperature limit has occurred"

	exit_code = 0
	current_warnings=""
	sticky_warnings=""

	gsub(/^throttled=/,"",vcgencmd_output)

	if ( vcgencmd_output ~ /0x[0-9a-fA-F]+/ ) {
		bits = vcgencmd_output
	} else {
		print "UNKNOWN - Invalid response from \"vcgencmd\""
		exit_code = 3
		exit 3
	}
}

{
	bits = strtonum(bits)
	bits_current_cnt = asorti(bits_current, sorted_bits_current, "@ind_num_desc")
	bits_sticky_cnt = asorti(bits_sticky, sorted_bits_sticky, "@ind_num_desc")


	masked_bits = and(bits, 0xF)
	for (i = 1; i <= bits_current_cnt; i++) {
		bit = strtonum(sorted_bits_current[i])

		if (masked_bits >= bit) {
			warning=sprintf("[0x%x] %s\n", bit, bits_current[bit])
			current_warnings=current_warnings warning
			masked_bits -= bit
			exit_code = 2
		}
		
	}

	
	if ( bits > 0x8 ) {

		masked_bits = and(bits, 0xF0000)
		for (i = 1; i <= bits_sticky_cnt; i++) {
			bit = strtonum(sorted_bits_sticky[i])

			if (masked_bits >= bit) {
				warning = sprintf("[0x%x] %s\n", bit, bits_sticky[bit])
				sticky_warnings = sticky_warnings warning
				masked_bits -= bit
			}
			
		}
	}
}

END { 
	if (exit_code < 3) { 


		if (exit_code > 0) {
			print "CRITICAL - There are active warnings!"
			print "Active warning(s):\n"
			printf current_warnings
		} else {
			print "OK - There are no active warnings!"
		}

		if (length(sticky_warnings)>0) {
			print "\nSticky warning(s):\n"
			print sticky_warnings
		}

	}

	exit exit_code
}
'

# Exit from shell script with exit code of awk
exit $?
