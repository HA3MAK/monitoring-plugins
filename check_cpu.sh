#!/bin/sh
#
#   Description: Linux CPU usage information collector plugin for Icinga2
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

FIRST_SAMPLE=$(grep '^cpu[0-9]*[[:space:]]' /proc/stat)
sleep 1s
LAST_SAMPLE=$(grep '^cpu[0-9]*[[:space:]]' /proc/stat)
PERF_DATA=""

for cpu in $(grep -o '^cpu[0-9]*[[:space:]]' /proc/stat)
do

	first_s=$(echo "${FIRST_SAMPLE}" |  grep -E "^${cpu}[[:space:]]+")
	last_s=$(echo "${LAST_SAMPLE}" |  grep -E "^${cpu}[[:space:]]+")

	current_data=$(echo "${first_s}\n${last_s}" |  ${AWK} '{
		if (NR == 1) {
			cpu_name=$1;
			usr1=$2;
			nice1=$3;
			sys1=$4;
			idle1=$5;
			iow1=$6;
			irq1=$7;
			sirq1=$8
			steal1=$9
			guest1=$10
			g_nice1=$11
		};

		if (NR == 2) {
			usr2=$2;
			nice2=$3;
			sys2=$4;
			idle2=$5;
			iow2=$6;
			irq2=$7;
			sirq2=$8
			steal2=$9
			guest2=$10
			g_nice2=$11
		};
	}

	END {

		usr=usr2-usr1;
		nice=nice2-nice1;
		sys=sys2-sys1;
		idle=idle2-idle1;
		iow=iow2-iow1;
		irq=irq2-irq1;
		sirq=sirq2-sirq1;
		steal=steal2-steal1;
		guest=guest2-guest1;
		g_nice=g_nice2-g_nice1;

		total_time=usr+nice+sys+idle+iow+irq+sirq+steal+guest+g_nice;

		usr_p=usr/total_time*100;
		nice_p=nice/total_time*100;
		sys_p=sys/total_time*100;
		idle_p=idle/total_time*100;
		iow_p=iow/total_time*100;
		irq_p=irq/total_time*100;
		sirq_p=sirq/total_time*100;
		steal_p=steel/total_time*100;
		guest_p=guest/total_time*100;
		g_nice_p=g_nice/total_time*100;



		printf "\047%s_usr\047=%.1f%% ", cpu_name, usr_p
		printf "\047%s_nice\047=%.1f%% ", cpu_name, nice_p
		printf "\047%s_sys\047=%.1f%% ", cpu_name, sys_p
		printf "\047%s_idle\047=%.1f%% ", cpu_name, idle_p
		printf "\047%s_wait\047=%.1f%% ", cpu_name, iow_p
		printf "\047%s_hw_irq\047=%.1f%% ", cpu_name, irq_p
		printf "\047%s_sw_irq\047=%.1f%% ", cpu_name, sirq_p
		printf "\047%s_steal\047=%.1f%% ", cpu_name, steal_p
		printf "\047%s_guest\047=%.1f%% ", cpu_name, guest_p
		printf "\047%s_guest_nice\047=%.1f%% ", cpu_name, g_nice_p
	}' 2>/dev/null)

	if [ $? -ne 0 ]
	then
		echo "UNKNOWN: Something went wrong! :("
		exit 3
	fi

	PERF_DATA="${PERF_DATA} ${current_data}"

done

echo "This plugin is only used for collect performance data!|${PERF_DATA}"
exit 0