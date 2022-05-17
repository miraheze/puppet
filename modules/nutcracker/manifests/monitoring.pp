# == Class: nutcracker::monitoring
#
# Provisions Icinga alerts for nutcracker.
#
class nutcracker::monitoring(
    Stdlib::Port $port = 11212,
) {
    monitoring::nrpe { 'nutcracker process':
        command => '/usr/lib/nagios/plugins/check_procs -c 1:1 -u nutcracker -C nutcracker',
    }

    monitoring::services { 'nutcracker port':
        check_command => 'tcp',
        vars          => {
            tcp_port    => $port,
        }
    }
}
