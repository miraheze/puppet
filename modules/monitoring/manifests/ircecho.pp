class monitoring::ircecho (
    String $mirahezebots_password = undef,
) {
    require_package(['python3-pyinotify', 'python3-irc'])

    file { '/usr/local/bin/ircecho':
        ensure => 'present',
        source => 'puppet:///modules/monitoring/bot/ircecho.py',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
        notify => Service['ircecho'],
    }


    $pyversion = $::lsbdistcodename ? {
        'bullseye' => 'python3.9',
        'buster'   => 'python3.7',
        'stretch'  => 'python3.5',
    }
    file { "/usr/local/lib/${pyversion}/dist-packages/ib3_auth.py":
        ensure => 'present',
        source => 'puppet:///modules/monitoring/bot/ib3_auth.py',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
        notify => Service['ircecho'],
    }

    $ircecho_logs = {
        '/var/log/icinga2/irc.log' => '#miraheze-sre',
    }

    file { '/etc/default/ircecho':
        ensure  => 'present',
        content => template('monitoring/bot/default.erb'),
        owner   => 'root',
        mode    => '0755',
        notify  => Service['ircecho'],
    }

    file { '/etc/default/ircecho_password':
        ensure  => 'present',
        content => $mirahezebots_password,
        owner   => 'root',
        group   => 'root',
        mode    => '0640',
        notify  => Service['ircecho'],
    }


    systemd::service { 'ircecho':
        ensure  => present,
        content => systemd_template('ircecho'),
        restart => true,
    }

    monitoring::services { 'IRCEcho':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_ircecho',
        },
    }
}
