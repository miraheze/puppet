# Class: mediawiki::cgroup

class mediawiki::cgroup {

    ensure_packages('cgroup-bin')

    # The cgroup-mediawiki-clean script is used as the release_agent
    # script for the cgroup. When the last task in the cgroup exits,
    # the kernel will run the script.

    file { '/usr/local/bin/cgroup-mediawiki-clean':
        source => 'puppet:///modules/mediawiki/cgroup/cgroup-mediawiki-clean',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    base::service_unit { 'mw-cgroup':
        ensure  => present,
        systemd => systemd_template('mw-cgroup'),
        refresh => false,
    }
}
