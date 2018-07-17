# == Class: lizardfs::master

class lizardfs::master (
    # misc4 ip
    $master_server = hiera('lizardfs_master_server', '185.52.3.121'),
) {

    require_package('lizardfs-master')

    file { '/var/lib/lizardfs/metadata.mfs':
        ensure  => 'present',
        replace => 'no',
        content => 'MFSM NEW',
        require => Package['lizardfs-master'],
    }

    file { '/etc/lizardfs/mfsmaster.cfg':
        ensure  => present,
        content => template('lizardfs/mfsmaster.cfg.erb'),
        require => Package['lizardfs-master'],
        notify  => Service['lizardfs-master'],
    }

    $module_path = get_module_path($module_name)
    $storage_ip = loadyaml("${module_path}/data/config.yaml")

    file { '/etc/lizardfs/mfsexports.cfg':
        ensure  => present,
        content => template('lizardfs/mfsexports.cfg.erb'),
        require => Package['lizardfs-master'],
        notify  => Service['lizardfs-master'],
    }

    file { '/etc/swift/object-server.conf':
        ensure  => present,
        content => template('swift/object-server.conf.erb'),
        require => Package['swift-object'],
        notify  => Service['swift-object'],
    }
    
    service { 'lizardfs-master':
        ensure => running,
    }
}
