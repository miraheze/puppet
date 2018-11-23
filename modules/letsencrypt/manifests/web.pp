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

    ufw::allow { "misc1 to port 5000":
        proto => 'tcp',
        port  => 5000,
        from  => '185.52.1.76',
    }

    icinga2::custom::services { 'MirahezeRenewSsl':
        check_command => 'tcp',
        vars          => {
            tcp_port    => '5000',
        },
    }
}
