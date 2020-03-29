class gluster::apt {
    # Needs to be manually updated when a majour update is released.
    # We pin this to 7.0 to prevent unintended updates to majour releases.
    apt::source { 'gluster_apt':
        comment  => 'GlusterFS',
        location => "https://download.gluster.org/pub/gluster/glusterfs/7/7.4/Debian/${::lsbdistcodename}/amd64/apt",
        release  => "${::lsbdistcodename}",
        repos    => 'main',
        key      => '80D15823B7FD1561F9F7BCDDDC30D7C23CBBABEE',
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
