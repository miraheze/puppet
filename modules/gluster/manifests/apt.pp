class gluster::apt {
    # For now work around an issue using amd64/apt failing when using version 8 of gluster
    # This should be "https://download.gluster.org/pub/gluster/glusterfs/8/LATEST/Debian/${::lsbdistcodename}/amd64/apt"
    # when https://github.com/gluster/glusterfs/issues/2741 is resolved.
    # Version 9 unaffected.
    apt::source { 'gluster_apt':
        comment  => 'GlusterFS',
        location => "https://download.gluster.org/pub/gluster/glusterfs/8/LATEST/Debian/${::lsbdistcodename}",
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
