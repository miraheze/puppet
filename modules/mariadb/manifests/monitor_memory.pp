class mariadb::monitor_memory (
    Integer[0, 100] $critical = 95,
    Integer[0, 100] $warning  = 90,
) {
    monitoring::nrpe { 'mariadb_memory':
        command => "/usr/lib/nagios/plugins/pmp-check-unix-memory -c ${critical} -w ${warning}",
        docs    => 'https://meta.miraheze.org/wiki/Tech:MariaDB',
    }
}
