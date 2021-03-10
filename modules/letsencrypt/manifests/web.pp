# class: letsencrypt::web
class letsencrypt::web {
    
    require_package('python3-flask', 'python3-filelock')

    file { '/usr/local/bin/mirahezerenewssl.py':
        ensure  => present,
        source  => 'puppet:///modules/letsencrypt/mirahezerenewssl.py',
        mode    => '0755',
        notify  => Service['mirahezerenewssl'],
    }

    systemd::service { 'mirahezerenewssl':
        ensure  => present,
        content => systemd_template('mirahezerenewssl'),
        restart => true,
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
