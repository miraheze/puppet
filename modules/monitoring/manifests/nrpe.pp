define monitoring::nrpe (
    String $command,
    VMlib::Ensure $ensure = present,
) {
    $title_safe  = regsubst($title, '[\W]', '-', 'G')
    @file { "/etc/nagios/nrpe.d/${title_safe}.cfg":
        ensure  => $ensure,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => template('monitoring/nrpecheck.erb'),
        notify  => Service['nagios-nrpe-server'],
    }

    if $ensure == 'present' {
        monitoring::services { $title:
            check_command => 'nrpe',
            vars          => {
                nrpe_command => "check_${title}",
                nrpe_timeout => '60s',
            },
        }
    }
}
