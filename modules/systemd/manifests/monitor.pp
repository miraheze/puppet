define systemd::monitor(
    VMlib::Ensure $ensure = present,
) {
    file { '/usr/lib/nagios/plugins/check_systemd_unit_status':
        ensure => $ensure,
        source => 'puppet:///modules/systemd/check_systemd_unit_status.sh',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    monitoring::nrpe { "Check unit status of ${title}":
        ensure  => $ensure,
        command => "/usr/bin/sudo /usr/lib/nagios/plugins/check_systemd_unit_status ${title}",
    }
}
