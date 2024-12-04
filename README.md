
# Monitoring plugins of HA3MAK

I use Nagios/Icinga/Icinga2 for many years and during this time I made many plugins. I decided to publish these on GitHub. You can use them and fork them but I can not take responsibility for using them! The plugins are mostly shell scripts that are as universal as it can be: they are using no bashisms and minimal dependencies(mostly awk).


## Plugins

#### check_cpu.sh

Used for collect CPU usage data. Doesn't expect any arguments and always will return with OK state.

#### check_memory.sh

Used for collect memory usage data. Doesn't expect any arguments and always will return with OK state.

#### check_netstats.sh

Used for collect information about current TCP, UDP and ICMP connections.

| Parameter    | Description                                                                            |
| :----------- | :------------------------------------------------------------------------------------- |
| `--treshold` | Sets "warning" and "critical" treshold for selected metrics. Can be used many times.   |
| `--help`     | Shows detailed help for usage.                                                         |


## Authors

- [@HA3MAK](https://www.github.com/HA3MAK)