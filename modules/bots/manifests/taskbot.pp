# class: bots::taskbot
class bots::taskbot {
    include bots

    $http_proxy      = lookup('http_proxy', {'default_value' => undef})
    $icinga_host     = lookup('icinga2_host', {'default_value' => 'mon181.fsslc.wtnet'})
    $icinga_password = lookup('passwords::icinga2::taskbot')
    $phorge_token    = lookup('passwords::phorge::monitoring_bot')

    file { '/etc/taskbot':
        ensure => directory,
        owner  => 'root',
        group  => 'irc',
        mode   => '0750',
    }

    file { '/etc/taskbot/taskbot.py':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        source  => 'puppet:///modules/bots/taskbot/taskbot.py',
        require => File['/etc/taskbot'],
        notify  => Service['taskbot'],
    }

    file { '/etc/taskbot/icinga-ca.crt':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        source  => 'puppet:///modules/bots/taskbot/icinga-ca.crt',
        require => File['/etc/taskbot'],
        notify  => Service['taskbot'],
    }

    file { '/etc/taskbot/config.json':
        ensure  => present,
        owner   => 'root',
        group   => 'irc',
        mode    => '0640',
        content => epp('bots/taskbot/config.json.epp', {
            'icinga_url'      => "https://${icinga_host}:5665",
            'icinga_password' => $icinga_password,
            'phorge_token'    => $phorge_token,
            'http_proxy'      => $http_proxy,
        }),
        require => File['/etc/taskbot'],
        notify  => Service['taskbot'],
    }

    systemd::service { 'taskbot':
        ensure  => present,
        content => systemd_template('taskbot'),
        restart => true,
        require => [
            File['/etc/taskbot/taskbot.py'],
            File['/etc/taskbot/icinga-ca.crt'],
            File['/etc/taskbot/config.json'],
        ],
    }

    monitoring::nrpe { 'Icinga Task Bot':
        command => '/usr/lib/nagios/plugins/check_procs -a taskbot.py -c 1:1',
    }

    monitoring::nrpe { 'Icinga Task Bot Sync':
        command => '/usr/lib/nagios/plugins/check_file_age -w 300 -c 900 -f /var/lib/taskbot/last_sync',
    }
}
