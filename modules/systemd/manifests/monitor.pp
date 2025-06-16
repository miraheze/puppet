define systemd::monitor {
    file { '/usr/lib/nagios/plugins/check_systemd_unit_status':
        source => 'puppet:///modules/systemd/check_systemd_unit_status',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    monitoring::nrpe { "Check unit status of ${title}":
        command => '/usr/bin/sudo /usr/lib/nagios/plugins/check_systemd_unit_status'
    }
}
