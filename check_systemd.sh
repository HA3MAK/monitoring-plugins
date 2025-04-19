#!/bin/sh
#
#   Description: Plugin for Icinga2 to check failed systemd units, timers and sockets
#   Version: 1.0
#   Date: 2025.04.19
#
#   Author: Mayer Karoly (HA3MAK)
#   E-mail: mayer.karoly@sinuslink.hu
#   Web:    https://github.com/HA3MAK/monitoring-plugins
#
SYSTEMCTL=$(which systemctl 2>/dev/null)
JQ=$(which jq 2>/dev/null)
SED=$(which sed 2>/dev/null)

#Dependency checks
if [ -z "${SYSTEMCTL}" ]
then
	echo "ERROR: \"systemctl\" was not found!"
	exit 2
fi

if [ -z "${JQ}" ]
then
	echo "ERROR: \"jq\" was not found!"
	exit 2
fi

if [ -z "${SED}" ]
then
	echo "ERROR: \"sed\" was not found!"
	exit 2
fi

# Init some variables
SYSTEMD_ITEM_TYPE="units timers sockets"
EXCEPTIONS_LIST=""

#Show the help
usage() {
	script_name=$(basename ${0})
	echo "Usage: ${script_name} [--type <units|timers|sockets|all>] [ --exception <unit, timer or socket name>]"
	echo ""
	echo "  This Icinga plugin checks if are there any failed systemd units, timers or sockets."
    echo ""
	echo ""
	echo "Options:"
	echo "  --type, -t       Systemd item types to check. Values can be: units, sockets, timers, all"
	echo "                   Default: all"
	echo "  --exception, -e  Ignore given unit, timer or socket."
	echo "                   Can be used many times."
	echo ""
	echo "  --help, -h       Shows this help."
	echo ""
	echo ""
	echo "Usage example:"
	echo ""
	echo "  ${script_name} --type all --exception postfix.service --exception man-db.timer"
	echo ""
}

test_type_arg() {
	#Determine the type of checks
	case "${1}" in
		units)
			#Check only for failed units
			SYSTEMD_ITEM_TYPE="units"
		;;
		timers)
			#Check only for failed timers
			SYSTEMD_ITEM_TYPE="timers"
		;;
		sockets)
			#Check only for failed sockets
			SYSTEMD_ITEM_TYPE="sockets"
		;;
		all)
			#Check for failed units, timers ans sockets also
			SYSTEMD_ITEM_TYPE="units timers sockets"
		;;
		*)
			#Invalid argument for --type. Exit with unknown state
			echo "UNKNOWN - Invalid type of systemd items: \"${1}\""
			echo "Possible values: units, timers, sockets or all"
			exit 3
		;;
	esac
}

test_exception_arg() {

	if [ -z "${1}" ]
	then
		#The exception can't be empty
		echo "UNKNOWN - Exception name must be given!"
		exit 3
	else
		#Add the string to the list
		EXCEPTION_LIST="${EXCEPTION_LIST}${1} "
	fi

}

#Parse the commandline arguments

while [ -n "${1}" ]
do
	case "${1}" in
		--help|-h)
			#Show help and exit
			usage
			exit 0
		;;
		--type|-t)
			#What do we check? units, timers, sockets or all?
			test_type_arg "${2}"
			shift
		;;
		--exception|-e)
			#Check and add exceptions
			test_exception_arg "${2}"
			shift
		;;
		*)
			#Invalid argument. Exit with unknown state..
			echo "UNKNOWN - Invalid argument: ${1}"
			exit 3
		;;
	esac
	shift
done

######################################################################

#Prepare $EXCEPTION_LIST for grep
EXCEPTION_LIST=$(echo "${EXCEPTION_LIST}" | ${SED} -e 's/ $//g' -e 's/ /\\|/g' -e 's/\-/\\-/g')
EXCEPTION_GREP=""
if [ ! -z "${EXCEPTION_LIST}" ]
then
	#We only need to pipe the jq output into grep when there are exception(s) defined
	EXCEPTION_GREP=" | grep -v \"${EXCEPTION_LIST}\""
fi

#Set some variables
EXIT_MSG="There are "
EXIT_MSG_EXTRA=""
TOTAL_FAILED_COUNT=0
TOTAL_FAILED_ITEMS=""
PERFDATA=""
#Do the check for the required types
for type in ${SYSTEMD_ITEM_TYPE}
do

	#Get list of failed items
	SYSTEMD_FAILED_ITEMS=$(eval "${SYSTEMCTL} list-${type} --failed --output=json --plain | ${JQ} -r .[].unit${EXCEPTION_GREP}")
	#Count failed items
	FAILED_ITEMS_COUNT=$(echo "${SYSTEMD_FAILED_ITEMS}" | wc -w)

	#Sum the failed items(in case of all...)
	TOTAL_FAILED_COUNT=$((${TOTAL_FAILED_COUNT}+${FAILED_ITEMS_COUNT}))
	TOTAL_FAILED_ITEMS="${TOTAL_FAILED_ITEMS}${SYSTEMD_FAILED_ITEMS}"
	#Create perfdata entry
	PERFDATA="${PERFDATA}'systemd_failed_${type}'=${FAILED_ITEMS_COUNT} "

	#Add current item to the exit message
	EXIT_MSG="${EXIT_MSG}${FAILED_ITEMS_COUNT} ${type}, "
	#If there were failed items list them in the extra output lines
	EXIT_MSG_EXTRA="${EXIT_MSG_EXTRA}${SYSTEMD_FAILED_ITEMS}"

done

#Some formatting
EXIT_MSG=$(echo "${EXIT_MSG}" | rev | cut -c3- | rev)
EXIT_MSG="${EXIT_MSG} in failed state!"

if [ ${TOTAL_FAILED_COUNT} -eq 0 ]
then
	#If there was no failed item
	ITEMS_TEXT=$(echo "${SYSTEMD_ITEM_TYPE}" | ${SED} -e 's/ /, /g' -e 's/, sockets/ or sockets/g')
	echo "OK - There are no failed systemd ${ITEMS_TEXT}|${PERFDATA}"
	exit 0
else
	#If there was minimum 1 failed item
	echo "CRITICAL - ${EXIT_MSG}|${PERFDATA}"
	echo "${TOTAL_FAILED_ITEMS}"
	exit 2
fi

#Never should reach this point
echo "UNKNOWN - Something went wrong. :("
exit 3

