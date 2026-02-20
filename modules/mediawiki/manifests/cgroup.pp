# === Class mediawiki::cgroup
class mediawiki::cgroup {
    if ($facts['os']['distro']['codename'] == 'trixie') {
        $ensure = 'absent'
    } else {
        $ensure = 'present'
    }

    # The cgroup-mediawiki-clean script is used as the release_agent
    # script for the cgroup. When the last task in the cgroup exits,
    # the kernel will run the script.

    file { '/usr/local/bin/cgroup-mediawiki-clean':
        ensure => $ensure,
        source => 'puppet:///modules/mediawiki/cgroup/cgroup-mediawiki-clean',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    $php_version = lookup('php::php_version', {'default_value' => '8.2'})
    systemd::service { 'cgroup':
        ensure  => $ensure,
        content => systemd_template('cgroup'),
        restart => false,
    }

    if $ensure == 'present' {
        grub::bootparam { 'cgroup_enable':
            value => 'memory',
        }

        grub::bootparam { 'swapaccount':
            value => '1',
        }

        # Disable cgroup memory accounting
        grub::bootparam { 'cgroup.memory':
            value => 'nokmem',
        }

        # Force use of cgroups v1
        grub::bootparam { 'systemd.unified_cgroup_hierarchy':
            value => '0',
        }
    }
}
