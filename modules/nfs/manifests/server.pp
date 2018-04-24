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

    exec { 'nfs-common reload systemd':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    file { '/lib/systemd/system/nfs-common.service':
        ensure  => absent,
        notify => Exec['nfs-common reload systemd'],
        require => Package['nfs-common'],
    }

    service { 'nfs-common':
        ensure  => running,
        require => File['/lib/systemd/system/nfs-common.service'],
    }

    service { 'rpcbind':
        ensure => running,
    }
}
