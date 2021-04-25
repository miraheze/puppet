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

    monitoring::services { 'IRC Log Server Bot':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_irc_logserverbot',
        },
    }
}
