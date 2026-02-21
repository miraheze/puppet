# class: irc::irclogserverbot
class irc::irclogserverbot(
    $nickname     = undef,
    $network      = undef,
    $network_port = '6697',
    $channel      = undef,
    $udp_port     = '5071',
) {
    include ::irc

    $mirahezebots_password = lookup('passwords::irc::mirahezebots')

    file { '/usr/local/bin/irclogserverbot.py':
        ensure  => present,
        content => template('irc/ircrcbot.py'),
        mode    => '0755',
        notify  => Service['irclogserverbot'],
    }

    systemd::service { 'irclogserverbot':
        ensure  => present,
        content => systemd_template('irclogserverbot'),
        restart => true,
    }

    monitoring::nrpe { 'IRC Log Server Bot':
        command => '/usr/lib/nagios/plugins/check_procs -a irclogserverbot.py -c 1:1'
    }
}
