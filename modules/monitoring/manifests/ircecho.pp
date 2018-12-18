class monitoring::ircecho (
    String $mirahezebots_password = undef,
) {
    require_package(['python3-pyinotify', 'python3-irc'])

    file { '/usr/local/bin/ircecho':
        ensure => 'present',
        source => 'puppet:///modules/monitoring/ircecho.py',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
        notify => Service['ircecho'],
    }

    file { '/usr/local/lib/python3.5/dist-packages/ib3_auth.py':
        ensure => 'present',
        source => 'puppet:///modules/monitoring/ib3_auth.py',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
        notify => Service['ircecho'],
    }

    $ircecho_logs = {
        "/var/log/icinga2/irc.log" => "#miraheze",
    }

    file { '/etc/default/ircecho':
        ensure  => 'present',
        content => template('monitoring/default.erb'),
        owner   => 'root',
        mode    => '0755',
        notify  => Service['ircecho'],
    }

    file { '/etc/defaults/ircecho_password':
        content => $mirahezebots_password,
        owner   => 'root',
        group   => 'root',
        mode    => '0640',
        notify  => Service['ircecho'],
    }

    exec { 'ircecho reload systemd':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    file { '/etc/systemd/system/ircecho.service':
        ensure => present,
        source => 'puppet:///modules/monitoring/bot/ircecho.systemd',
        notify => Exec['ircecho reload systemd'],
    }

    service { 'ircecho':
        ensure  => running,
        require => File['/etc/systemd/system/ircecho.service'],
    }
}
