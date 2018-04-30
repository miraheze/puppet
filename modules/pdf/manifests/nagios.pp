# == Class pdf::nagios
# Sets up icinga alerts for an Offline Content Generator instance.
#
class pdf::nagios {

    file { '/usr/lib/nagios/plugins/check_ocg_health':
        ensure  => absent,
    }

    icinga::service { 'ocg_health':
        ensure        => absent,
        description   => 'OCG health',
        check_command => 'check_nrpe_1arg!check_ocg_health',
    }
}
