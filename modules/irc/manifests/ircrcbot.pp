# class: irc::ircrcbot
class irc::ircrcbot(
    $nickname     = undef,
    $network      = undef,
    $network_port = '6697',
    $channel      = undef,
    $udp_port     = '5070',
) {
    include ::irc

    $mirahezebots_password = lookup('passwords::irc::mirahezebots')

    file { '/usr/local/bin/ircrcbot.py':
        ensure  => present,
        content => template('irc/ircrcbot.py'),
        mode    => '0755',
        notify  => Service['ircrcbot'],
    }

    systemd::service { 'ircrcbot':
        ensure  => present,
        content => systemd_template('ircrcbot'),
        restart => true,
    }

    monitoring::nrpe { 'IRC RC Bot':
        command => '/usr/lib/nagios/plugins/check_procs -a ircrcbot.py -c 1:1'
    }
}
