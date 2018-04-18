# NFS Client
class nfs::client {
    package { 'nfs-common':
        ensure => present,
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
}
