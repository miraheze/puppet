# == Class ocg::nagios
# Sets up icinga alerts for an Offline Content Generator instance.
#
class ocg::nagios {

    file { '/usr/lib/nagios/plugins/check_ocg_health':
        source  => 'puppet:///modules/ocg/nagios/check_ocg_health',
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
    }

    icinga::service { 'ocg_health':
        description   => 'OCG health',
        check_command => 'check_ocg_health!8142',
    }
}
