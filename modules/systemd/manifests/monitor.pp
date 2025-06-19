define systemd::monitor(
    VMlib::Ensure              $ensure   = present,
    Boolean                    $critical = false,
    Optional[Stdlib::HTTPSUrl] $docs     = undef,
) {
    if !defined(File['/usr/lib/nagios/plugins/check_systemd_unit_status']) {
        file { '/usr/lib/nagios/plugins/check_systemd_unit_status':
            source => 'puppet:///modules/systemd/check_systemd_unit_status.sh',
            mode   => '0755',
        }
    }

    monitoring::nrpe { "Check unit status of ${title}":
        ensure   => $ensure,
        docs     => $docs,
        critical => $critical,
        command  => "/usr/lib/nagios/plugins/check_systemd_unit_status ${title}",
    }
}
