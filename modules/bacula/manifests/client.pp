# Client class for all backup servers
class bacula::client {
    package { 'bacula-client':
        ensure => present,
    }

    service { 'bacula-fd':
        ensure  => running,
        require => Package['bacula-client'],
    }

    file { ['/bacula', '/bacula/restore']:
        ensure => directory,
        owner  => 'bacula',
    }

    $password = lookup('passwords::bacula::director')

    file { '/etc/bacula/bacula-fd.conf':
        ensure  => present,
        content => template('bacula/client/bacula-fd.conf'),
        notify  => Service['bacula-fd'],
    }

    $firewall_rules = query_facts('Class[Bacula::Director]', ['ipaddress', 'ipaddress6'])
    $firewall_rules_mapped = $firewall_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
    $firewall_rules_str = join($firewall_rules_mapped, ' ')
    ferm::service { 'bacula client 9102':
        proto  => 'tcp',
        port   => '9102',
        srange => "(${firewall_rules_str})",
    }
}
