# class: monitoring::taskbot
class monitoring::taskbot {
    $icinga_password = lookup('passwords::icinga2::taskbot')
    $phorge_token = lookup('passwords::phorge::icingabot')
    $http_proxy = lookup('http_proxy', {'default_value' => undef})

    icinga2::object::apiuser { 'taskbot':
        ensure      => present,
        password    => $icinga_password,
        permissions => ['events/StateChange', 'objects/query/Service'],
        target      => '/etc/icinga2/conf.d/api-users.conf',
        require     => Package['icinga2'],
        notify      => Service['icinga2'],
    }

    file { '/etc/icinga-taskbot':
        ensure => directory,
        owner  => 'root',
        group  => 'nagios',
        mode   => '0750',
    }

    file { '/usr/local/bin/icinga-taskbot.py':
        ensure => present,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
        source => 'puppet:///modules/monitoring/bot/taskbot.py',
        notify => Service['icinga-taskbot'],
    }

    file { '/etc/icinga-taskbot/config.json':
        ensure  => present,
        owner   => 'root',
        group   => 'nagios',
        mode    => '0640',
        content => epp('monitoring/bot/taskbot.json.epp', {
            'icinga_url'      => "https://${facts['networking']['fqdn']}:5665",
            'icinga_password' => $icinga_password,
            'phorge_token'    => $phorge_token,
            'http_proxy'      => $http_proxy,
        }),
        require => File['/etc/icinga-taskbot'],
        notify  => Service['icinga-taskbot'],
    }

    systemd::service { 'icinga-taskbot':
        ensure  => present,
        content => systemd_template('taskbot'),
        restart => true,
        require => [
            File['/usr/local/bin/icinga-taskbot.py'],
            File['/etc/icinga-taskbot/config.json'],
        ],
    }

    monitoring::nrpe { 'Icinga Task Bot':
        command => '/usr/lib/nagios/plugins/check_procs -a icinga-taskbot.py -c 1:1',
    }
}
