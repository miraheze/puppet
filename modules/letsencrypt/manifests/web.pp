# class: letsencrypt::web
class letsencrypt::web {
    
    require_package('python3-flask', 'python3-filelock')

    file { '/usr/local/bin/mirahezerenewssl.py':
        ensure  => present,
        source  => 'puppet:///modules/letsencrypt/mirahezerenewssl.py',
        mode    => '0755',
        notify  => Service['mirahezerenewssl'],
    }

    exec { 'mirahezerenewssl reload systemd':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    file { '/etc/systemd/system/mirahezerenewssl.service':
        ensure => present,
        source => 'puppet:///modules/letsencrypt/mirahezerenewssl.systemd',
        notify => Exec['mirahezerenewssl reload systemd'],
    }

    service { 'mirahezerenewssl':
        ensure  => 'running',
        require => File['/etc/systemd/system/mirahezerenewssl.service'],
    }

    $firewall = query_facts('Class[Role::Icinga2]', ['ipaddress', 'ipaddress6'])
    $firewall.each |$key, $value| {
        ufw::allow { "Icinga 5000 ${value['ipaddress']}":
            proto => 'tcp',
            port  => 5000,
            from  => $value['ipaddress'],
        }

        ufw::allow { "Icinga 5000 ${value['ipaddress6']}":
            proto => 'tcp',
            port  => 5000,
            from  => $value['ipaddress6'],
        }
    }

    monitoring::services { 'MirahezeRenewSsl':
        check_command => 'tcp',
        vars          => {
            tcp_port    => '5000',
        },
    }
}
