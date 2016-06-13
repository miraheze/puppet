# NFS server
define nfs::server (
    $mountroot   = '',
    $exportsfile = '',
){
    package { ['nfs-kernel-server', 'nfs-common' ]:
        ensure => present,
    }

    file { $mountroot:
        ensure => directory,
        owner  => 'nobody',
        group  => 'nogroup',
    }

    file { '/etc/exports':
        ensure => present,
        source => $exportsfile,
        notify => Service['nfs-kernel-server'],
    }

    service { 'nfs-kernel-server':
        ensure => running,
    }

    service { 'nfs-common':
        ensure => running,
    }

    service { 'rpcbind':
        ensure => running,
    }

}
