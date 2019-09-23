class gluster::apt {
    # Needs to be manually updated when a update is released.
    # We pin this to 6.5 to prevent unintended updates.
    apt::source { 'gluster_apt':
        comment  => 'GlusterFS',
        location => "https://download.gluster.org/pub/gluster/glusterfs/6/6.5/Debian/${::lsbdistcodename}/amd64/apt",
        release  => "${::lsbdistcodename}",
        repos    => 'main',
        key      => '126C0D24BD8A2942CC7DF8AC7638D0442B90D010',
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
