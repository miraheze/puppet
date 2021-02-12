# class: irc::irclogbot
class irc::irclogbot {
    include ::irc

    file { '/etc/irclogbot':
        ensure => directory,
    }

    git::clone { 'mwclient':
        ensure    => present,
        directory => '/etc/irclogbot/mwclient',
        origin    => 'https://github.com/mwclient/mwclient',
        require   => File['/etc/irclogbot'],
    }

    $mirahezebots_password = lookup('passwords::irc::mirahezebots')
    $mirahezelogbot_password = lookup('passwords::mediawiki::mirahezelogbot')

    file { '/etc/irclogbot/adminlog.py':
        ensure => present,
        source => 'puppet:///modules/irc/logbot/adminlog.py',
        notify => Service['logbot'],
    }

    file { '/etc/irclogbot/adminlogbot.py':
        ensure => present,
        source => 'puppet:///modules/irc/logbot/adminlogbot.py',
        mode   => '0755',
        notify => Service['logbot'],
    }

    file { '/etc/irclogbot/config.py':
        ensure  => present,
        content => template('irc/logbot/config.py'),
        notify  => Service['logbot'],
    }

    systemd::service { 'logbot':
        ensure  => present,
        content => systemd_template('logbot'),
        restart => true,
    }

    monitoring::services { 'IRC Log Bot':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_irc_logbot',
        },
    }
}
