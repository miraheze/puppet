# == Class: lizardfs::storage

class lizardfs::storage (
    # misc4 ip
    $master_server = hiera('lizardfs_master_server', '185.52.3.121'),
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
        ensure => running,
    }
}
