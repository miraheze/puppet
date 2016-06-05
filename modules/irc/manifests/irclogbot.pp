class irc::irclogbot {
    include ::irc

    file { '/etc/irclogbot':
        ensure => directory,
    }

    git::clone { 'mwclient':
        ensure => present,
        directory => '/etc/irclogbot/mwclient',
        origin => 'https://github.com/mwclient/mwclient',
        require => File['/etc/irclogbot'],
    }

    file { '/etc/irclogbot/adminlog.py':
        ensure => present,
        source => 'puppet:///modules/irc/logbot/adminlog.py',
    }

    file { '/etc/irclogbot/adminlogbot.py':
        ensure  => present,
        source  => 'puppet:///modules/irc/logbot/adminlogbot.py',
        mode    => 0755,
    }

    file { '/etc/irclogbot/config.py':
        ensure  => present,
        content => template('irc/logbot/config.py'),
    }

    file { '/etc/init.d/adminbot':
        ensure  => present,
        source  => 'puppet:///modules/irc/logbot/adminbot.initd',
    }

    exec { 'systemctl daemon-reload':
        path        => '/bin',
        refreshonly => true,
    }

    file { '/etc/systemd/system/adminbot.service':
        ensure  => present,
        source  => 'puppet:///modules/irc/logbot/adminbot.systemd',
        notify  => Exec['systemctl daemon-reload'],
    }
}
