define monitoring::nrpe (
    String $command,
    VMlib::Ensure $ensure = present,
    Boolean $critical = false,
    Optional[Stdlib::HTTPSUrl] $docs = undef,
    Optional[Monitoring::PhorgeTask] $phorge_task = undef,
    Array[Monitoring::PhorgeProject] $phorge_projects = [],
) {
    $title_safe  = regsubst($title, '[\W]', '-', 'G')
    @file { "/etc/nagios/nrpe.d/${title_safe}.cfg":
        ensure  => $ensure,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => template('monitoring/nrpecheck.cfg'),
        notify  => Service['nagios-nrpe-server'],
        tag     => 'nrpe',
    }

    if $ensure == 'present' {
        monitoring::services { $title:
            check_command   => 'nrpe',
            docs            => $docs,
            critical        => $critical,
            phorge_task     => $phorge_task,
            phorge_projects => $phorge_projects,
            vars            => {
                nrpe_command => "check_${title}",
                nrpe_timeout => '60',
            },
        }
    }
}
