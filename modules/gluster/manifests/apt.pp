class gluster::apt {
    apt::source { 'gluster_apt':
        comment  => 'GlusterFS',
        location => "https://download.gluster.org/pub/gluster/glusterfs/9/LATEST/Debian/${::lsbdistcodename}/amd64/apt",
        release  => "${::lsbdistcodename}",
        repos    => 'main',
        key      => 'F9C958A3AEE0D2184FAD1CBD43607F0DC2F8238C',
        notify   => Exec['apt_update_gluster'],
    }

    apt::pin { 'gluster_pin':
        priority        => 600,
        origin          => 'download.gluster.org'
    }

    # First installs can trip without this
    exec {'apt_update_gluster':
        command     => '/usr/bin/apt-get update',
        refreshonly => true,
        logoutput   => true,
        require     => Apt::Pin['gluster_pin'],
    }
}
