# class: irc::ircrcbot
class irc::ircrcbot(
    $nickname     = undef,
    $network      = undef,
    $network_port = '6667',
    $channel      = undef,
    $udp_port     = '5070',
    $sleeptime    = '0.5',
) {
    include ::irc

    $mirahezebots_password = hiera('passwords::irc::mirahezebots')

    file { '/usr/local/bin/ircrcbot.py':
        ensure  => present,
        content => template('irc/ircrcbot.py'),
        mode    => '0755',
        notify  => Service['ircrcbot'],
    }

    file { '/etc/init.d/ircrcbot':
        ensure => present,
        source => 'puppet:///modules/irc/ircrcbot/ircrcbot.initd',
        mode   => '0755',
        notify => Service['ircrcbot'],
    }

    exec { 'IRCRCbot reload systemd':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    file { '/etc/systemd/system/ircrcbot.service':
        ensure => present,
        source => 'puppet:///modules/irc/ircrcbot/ircrcbot.systemd',
        notify => Exec['IRCRCbot reload systemd'],
    }

    service { 'ircrcbot':
        ensure  => 'running',
        require => File['/etc/systemd/system/ircrcbot.service'],
    }

    icinga::service { 'ircrcbot':
        description   => 'IRC RC Bot',
        check_command => 'check_nrpe_1arg!check_irc_rcbot',
    }
}
