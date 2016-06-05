class irc::irclogbot {
    include ::irc

    file { '/etc/irclogbot':
        esnure => directory,
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
        ensure => present,
        source => 'puppet:///modules/irc/logbot/adminlogbot.py',
    }

    file { '/etc/irclogbot/config.py':
        ensure  => present,
        content => template('irc/logbot/config.py'),
    }
}
