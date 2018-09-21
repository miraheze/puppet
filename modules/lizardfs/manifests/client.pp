#
# == Define: lizardfs::client
#
# 'lizardfs::client': Installs client on host and mounts a LizardFS mount point.
#
# This class follows the recommendations of the "Puppet Labs Style Guide":
# http://docs.puppetlabs.com/guides/style_guide.html . If you want to
# contribute, please check your code with puppet-lint.
#
# === Authors
#
# Copyright (c) Achraf Cherti (aka Asher256)
#
# License: Apache 2.0
# Contact: asher256@gmail.com
# URL: https://github.com/Asher256/puppet-lizardfs
#
# === Examples
#
# ::lizardfs::client {'/mnt/lizardfs': }
#
# === Parameters
#
# [*ensure*]
#   Default value: 'mount'
#   Add the mount point to fstab and mount it automatically 'absent' to remove
#   the mount point (This variable is passed to mount{})
#
# [*lizardfs_master*]
#   The LizardFS hostname or IP address
#
# [*lizardfs_port*]
#   The LizardFS's port
#
# [*mountpoint*]
#   The directory where the LizardFS will be mounted.
#   If this variable is not defined, $name is used to define the local mount point.
#
# [*options*]
#   The mfsmount options. Example: "noauto"
#

define lizardfs::client(
    Integer $lizardfs_port = 9421,
    String $lizardfs_master = hiera('lizardfs_master_server', '185.52.3.121'),
    Optional[String] $mountpoint = undef,
    Optional[String] $options = undef,
    String $ensure = 'mounted',
    Boolean $create_mountpoint = false,
) {
    if $ensure == 'absent' {
        mount { $mountpoint:
          ensure => 'absent',
        }
    } else {
        require_package('lizardfs-client')

        $real_mountpoint = $mountpoint ? {
            undef   => $name,
            default => $mountpoint
        }

        $base_options = "mfsmaster=${lizardfs_master},mfsport=${lizardfs_port}"

        $mount_options = $options ? {
            undef   => $base_options,
            default => "${base_options},${options}",
        }

        if $create_mountpoint {
            exec { $real_mountpoint:
                command => "/bin/mkdir -p '${real_mountpoint}'",
                user    => 'root',
                group   => 'root',
                creates => $real_mountpoint,
                before  => Mount[$real_mountpoint],
            }
        }

        mount { $real_mountpoint:
          ensure   => $ensure,
          device   => 'mfsmount',
          fstype   => 'fuse',
          options  => $mount_options,
          remounts => false,
          require  => Package['lizardfs-client'],
        }
    }
}

# vim:et:sw=2:ts=2:sts=2:tw=0:fenc=utf-8
