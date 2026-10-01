# class: bots::salbot
class bots::salbot {
    include bots

    $http_proxy   = lookup('http_proxy', {'default_value' => undef})
    $irc_password = lookup('passwords::irc::salbot')
    $phorge_token = lookup('passwords::phorge::salbot')

    file { '/etc/salbot':
        ensure => directory,
        owner  => 'root',
        group  => 'irc',
        mode   => '0750',
    }

    file { '/etc/salbot/salbot.py':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        source  => 'puppet:///modules/bots/salbot/salbot.py',
        require => File['/etc/salbot'],
        notify  => Service['salbot'],
    }

    file { '/etc/salbot/config.json':
        ensure  => present,
        owner   => 'root',
        group   => 'irc',
        mode    => '0640',
        content => epp('bots/salbot/config.json.epp', {
            'http_proxy'   => $http_proxy,
            'irc_password' => $irc_password,
            'phorge_token' => $phorge_token,
        }),
        require => File['/etc/salbot'],
        notify  => Service['salbot'],
    }

    systemd::service { 'salbot':
        ensure  => present,
        content => systemd_template('salbot'),
        restart => true,
        require => [
            File['/etc/salbot/salbot.py'],
            File['/etc/salbot/config.json'],
        ],
    }

    monitoring::nrpe { 'SAL Phorge Bot':
        command => '/usr/lib/nagios/plugins/check_procs -a salbot.py -c 1:1',
    }
}
