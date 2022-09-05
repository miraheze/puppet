class gluster::apt (
    Optional[String] $http_proxy = lookup('http_proxy', {'default_value' => undef})
) {

    if $http_proxy {
        file { '/etc/apt/apt.conf.d/01gluster':
            ensure  => present,
            content => template('gluster/apt/01gluster.erb'),
            before  => Apt::Source['gluster_apt'],
        }
    }

    file { '/etc/apt/trusted.gpg.d/gluster.gpg':
        ensure => present,
        source => 'puppet:///modules/gluster/apt/gluster.gpg',
    }

    apt::source { 'gluster_apt':
        comment  => 'GlusterFS',
        location => "https://download.gluster.org/pub/gluster/glusterfs/10/LATEST/Debian/${::lsbdistcodename}/amd64/apt",
        release  => $::lsbdistcodename,
        repos    => 'main',
        require  => File['/etc/apt/trusted.gpg.d/gluster.gpg'],
        notify   => Exec['apt_update_gluster'],
    }

    apt::pin { 'gluster_pin':
        priority => 600,
        origin   => 'download.gluster.org'
    }

    # First installs can trip without this
    exec {'apt_update_gluster':
        command     => '/usr/bin/apt-get update',
        refreshonly => true,
        logoutput   => true,
        require     => Apt::Pin['gluster_pin'],
    }
}
