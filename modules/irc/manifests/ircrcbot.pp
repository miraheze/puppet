# class: irc::ircrcbot
class irc::ircrcbot(
    $nickname     = undef,
    $network      = undef,
    $network_port = '6697',
    $channel      = undef,
    $udp_port     = '5070',
    $sleeptime    = '0.5',
) {
    include ::irc

    $mirahezebots_password = lookup('passwords::irc::mirahezebots')

    file { '/usr/local/bin/ircrcbot.py':
        ensure  => present,
        content => template('irc/ircrcbot.py'),
        mode    => '0755',
        notify  => Service['ircrcbot'],
    }

    systemd::syslog { 'ircrcbot':
        readable_by  => 'all',
        base_dir     => '/var/log',
        group        => 'root',
        owner        => 'irc',
        log_filename => 'ircrcbot.log',
    }

    systemd::service { 'ircrcbot':
        ensure  => present,
        content => systemd_template('ircrcbot'),
        restart => true,
    }

    monitoring::services { 'IRC RC Bot':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_irc_rcbot',
        },
    }
}
