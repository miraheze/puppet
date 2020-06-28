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

    $firewall = query_facts('Class[Bacula::Director]', ['ipaddress', 'ipaddress6'])
    $firewall.each |$key, $value| {
        ufw::allow { "bacula 9102 ${value['ipaddress']}":
            proto => 'tcp',
            port  => 9102,
            from  => $value['ipaddress'],
        }

        ufw::allow { "bacula 9102 ${value['ipaddress6']}":
            proto => 'tcp',
            port  => 9102,
            from  => $value['ipaddress6'],
        }
    }
}
