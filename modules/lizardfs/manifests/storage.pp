# == Class: lizardfs::storage

class lizardfs::storage(
    String $master_server = hiera('lizardfs_master_server', '185.52.1.144'),
) {
    require_package('lizardfs-chunkserver')

    file { '/srv/mediawiki-static':
        ensure  => directory,
        owner   => 'lizardfs',
        group   => 'lizardfs',
        require => Package['lizardfs-chunkserver'],
    }

    file { '/etc/lizardfs/mfschunkserver.cfg':
        ensure  => present,
        content => template('lizardfs/mfschunkserver.cfg.erb'),
        require => Package['lizardfs-chunkserver'],
        notify  => Service['lizardfs-chunkserver'],
    }

    file { '/etc/lizardfs/mfshdd.cfg':
        ensure  => present,
        content => template('lizardfs/mfshdd.cfg.erb'),
        require => Package['lizardfs-chunkserver'],
        notify  => Service['lizardfs-chunkserver'],
    }
    
    service { 'lizardfs-chunkserver':
        ensure   => running,
        enable   => true,
        provider => 'systemd',
        require  => Package['lizardfs-chunkserver'],
        restart  => '/bin/systemctl reload lizardfs-chunkserver.service',
    }

    $module_path = get_module_path($module_name)
    $firewall = loadyaml("${module_path}/data/storage_firewall.yaml")

    $firewall.each |$firewall_key, $firewall_value| {
        # clients access chunkserver
        ufw::allow { "lizardfs ${firewall_key} 9421":
            proto => 'tcp',
            port  => 9422,
            from  => $firewall_value,
        }
    }

    monitoring::services { 'Lizardfs Chunkserver Port':
        check_command => 'tcp',
        vars          => {
            tcp_port    => '9422',
        },
    }

    if hiera('lizardfs_client', false) {
        # Used to backup with bacula
        ::lizardfs::client { '/mnt/mediawiki-static':
            create_mountpoint => true,
            options           => 'big_writes,nosuid,nodev,noatime',
        }
    }
}
