# class: irc::jouncebot
class irc::jouncebot {
    include ::irc

    file { '/etc/jouncebot':
        ensure => directory,
    }

    require_package(['python3-mwclient', 'python-dateutil', 'python-pytz', 'python-lxml', 'python-pyyaml'])

    $mirahezebots_password = hiera('passwords::irc::mirahezebots')
    $mirahezelogbot_password = hiera('passwords::mediawiki::mirahezelogbot')

    file { '/etc/jouncebot/jouncebot.yaml':
        ensure  => present,
        content => template('irc/jouncebot/jouncebot.yaml'),
        notify  => Service['jouncebot'],
    }

    exec { 'jouncebot reload systemd':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    file { '/etc/systemd/system/jouncebot.service':
        ensure => present,
        source => 'puppet:///modules/irc/jouncebot/jouncebot.systemd',
        notify => Exec['jouncebot reload systemd'],
    }

    service { 'jouncebot':
        ensure  => 'running',
        require => File['/etc/systemd/system/jouncebot.service'],
    }

    if hiera('base::monitoring::use_icinga2', false) {
        icinga2::custom::services { 'IRC Jounce Bot':
            check_command => 'nrpe',
            vars          => {
                nrpe_command => 'check_irc_jouncebot',
            },
        }
    } else {
        icinga::service { 'ircjouncebot':
            description   => 'IRC Jounce Bot',
            check_command => 'check_nrpe_1arg!check_irc_jouncebot',
        }
    }
}
