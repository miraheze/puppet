# Class: mediawiki::cgroup

class mediawiki::cgroup {

    ensure_packages('cgroup-bin')

    shellvar { 'GRUB_CMDLINE_LINUX':
        ensure       => present,
        target       => '/etc/default/grub',
        value        => 'cgroup_enable=memory',
        array_append => true,
    }

    shellvar { 'GRUB_CMDLINE_LINUX':
        ensure       => present,
        target       => '/etc/default/grub',
        value        => 'swapaccount=1',
        array_append => true,
    }

    # The cgroup-mediawiki-clean script is used as the release_agent
    # script for the cgroup. When the last task in the cgroup exits,
    # the kernel will run the script.

    file { '/usr/local/bin/cgroup-mediawiki-clean':
        source => 'puppet:///modules/mediawiki/cgroup/cgroup-mediawiki-clean',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    systemd::service { 'mw-cgroup':
        ensure  => present,
        content => systemd_template('mw-cgroup'),
        restart => false,
    }

    shellvar { 'GRUB_CMDLINE_LINUX':
        ensure       => present,
        target       => '/etc/default/grub',
        value        => 'cgroup.memory=nokmem',
        array_append => true,
    }
}
