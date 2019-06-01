# class: vpncloud
class vpncloud(
    String $server_ip = '0.0.0.0',
){
    file { '/opt/vpncloud_1.0.0_amd64.deb':
        ensure  => present,
        source  => 'puppet:///modules/vpncloud/vpncloud_1.0.0_amd64.deb',
    }

    package { 'vpncloud':
        ensure      => installed,
        provider    => dpkg,
        source      => '/opt/vpncloud_1.0.0_amd64.deb',
        require     => File['/opt/vpncloud_1.0.0_amd64.deb'],
    }

    $shared_key = hiera('passwords::vpncloud::shared_key')

    file { '/etc/vpncloud/miraheze-internal.net':
        ensure  => present,
        content  => template('vpncloud/miraheze-internal.net.erb'),
        notify  => Service['vpncloud@miraheze-internal'],
        require => Package['vpncloud'],
    }
    
    service { 'vpncloud@miraheze-internal':
        ensure      => running,
        hasrestart  => true,
        provider    => 'systemd',
        enable      => true,
        restart     => '/bin/systemctl reload vpncloud',
        require     => File['/etc/vpncloud/miraheze-internal.net'],
    }
}
