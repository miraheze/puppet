# class: bots::icingabot
class bots::icingabot {
    include bots

    $http_proxy      = lookup('http_proxy', {'default_value' => undef})
    $icinga_host     = lookup('icinga2_host', {'default_value' => 'mon181.fsslc.wtnet'})
    $icinga_password = lookup('passwords::icinga2::icingabot')
    $irc_password    = lookup('passwords::irc::mirahezebots')
    $phorge_token    = lookup('passwords::phorge::monitoring_bot')

    file { '/etc/icingabot':
        ensure => directory,
        owner  => 'root',
        group  => 'irc',
        mode   => '0750',
    }

    file { '/etc/icingabot/icingabot.py':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        source  => 'puppet:///modules/bots/icingabot/icingabot.py',
        require => File['/etc/icingabot'],
        notify  => Service['icingabot'],
    }

    file { '/etc/icingabot/icinga-ca.crt':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        source  => 'puppet:///modules/bots/icingabot/icinga-ca.crt',
        require => File['/etc/icingabot'],
        notify  => Service['icingabot'],
    }

    file { '/etc/icingabot/config.json':
        ensure  => present,
        owner   => 'root',
        group   => 'irc',
        mode    => '0640',
        content => epp('bots/icingabot/config.json.epp', {
            'icinga_url'      => "https://${icinga_host}:5665",
            'icinga_password' => $icinga_password,
            'irc_password'    => $irc_password,
            'phorge_token'    => $phorge_token,
            'http_proxy'      => $http_proxy,
        }),
        require => File['/etc/icingabot'],
        notify  => Service['icingabot'],
    }

    systemd::service { 'icingabot':
        ensure  => present,
        content => systemd_template('icingabot'),
        restart => true,
        require => [
            File['/etc/icingabot/icingabot.py'],
            File['/etc/icingabot/icinga-ca.crt'],
            File['/etc/icingabot/config.json'],
            Systemd::Service['taskbot'],
        ],
    }

    monitoring::nrpe { 'Icinga Bot':
        command => '/usr/lib/nagios/plugins/check_procs -a icingabot.py -c 1:1',
    }

    monitoring::nrpe { 'Icinga Bot Phorge Sync':
        command => '/usr/lib/nagios/plugins/check_file_age -w 300 -c 900 -f /var/lib/icingabot/last_sync',
    }

    monitoring::nrpe { 'Icinga Bot IRC':
        command => '/usr/lib/nagios/plugins/check_file_age -w 300 -c 900 -f /var/lib/icingabot/irc_alive',
    }
}
