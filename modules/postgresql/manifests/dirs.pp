# Class: postgresql::dirs
#
# This class creates postgresql directories. It's split off from the rest of the
# classes in order to allow requiring it without causing dependency loops. You
# should not be using it directly
#
# Parameters:
#   ensure
#       Defaults to present
#   root_dir
#       The root directory for postgresql data. The actual directory will be
#       "${root_dir}/${pgversion}/main".
#
# Actions:
#  Create postgres directories
#
# Requires:
#
# Sample Usage:
#  include postgresql::dirs
#
class postgresql::dirs(
    VMlib::Ensure $ensure    = 'present',
    String $root_dir  = '/var/lib/postgresql',
    Optional[Numeric] $pgversion = undef,
) {
    $_pgversion = $pgversion ? {
        undef   => $facts['os']['distro']['codename'] ? {
            'bookworm' => 15,
            'bullseye' => 13,
            default   => 11,
        },
        default => $pgversion,
    }
    $data_dir = "${root_dir}/${_pgversion}/main"

    file {  [ $root_dir, "${root_dir}/${_pgversion}" ] :
        ensure => ensure_directory($ensure),
        owner  => 'postgres',
        group  => 'postgres',
        mode   => '0755',
    }

    file { $data_dir:
        ensure => ensure_directory($ensure),
        owner  => 'postgres',
        group  => 'postgres',
        mode   => '0700',
    }
}
