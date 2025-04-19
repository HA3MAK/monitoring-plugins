
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

#### check_systemd.sh

This plugin is responsible for monitoring systemd units, timers and/or sockets. If there's one or more
systemd units in failed state it goes to critical state.

| Parameter    | Description                                                                            |
| :----------- | :------------------------------------------------------------------------------------- |
| `--type`     | Systemd item types to check. Values can be: units, sockets, timers, all Default: all   |
| `--exception`| Ignore given unit, timer or socket. Can be used many times.                            |
| `--help`     | Shows detailed help for usage.                                                         |

#### check_uptime.sh

This plugin alerts when host was restarted. It goes critical when restart happened but the next check will
be ok again. To keep it in "critical" state while you manually set it back to "ok" you should use the
Icinga2 Service definition below.

| Parameter    | Description                                                                            |
| :----------- | :------------------------------------------------------------------------------------- |
| `--help`     | Shows detailed help for usage.                                                         |

```text
apply Service "Uptime" {
	import "generic-service"
	command_endpoint = host.vars.client_endpoint

	check_command = "custom_uptime"

	var that = this
	vars.uptime_state = function() use(that) {
		return if (that.last_check_result && that.last_check_result.state == 2) { that.last_check_result.state } else { "" }
	}

	assign where [...]
}
```

## Authors

- [@HA3MAK](https://www.github.com/HA3MAK)