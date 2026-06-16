# @summary
#   Installs IcingaDB Redis server
#
# @api private
#
class icingadb::redis::install {
  assert_private()

  contain icinga::redis

  $package_name    = $icingadb::redis::globals::package_name
  $manage_packages = $icingadb::redis::manage_packages
  $user            = $icingadb::redis::globals::user
  $log_dir         = $icingadb::redis::globals::log_dir

  if $facts['os']['family'] == 'Debian' {
    $group = 'adm'
    $mode  = '2750'
  } else {
    $group = $icingadb::redis::globals::group
    $mode  = '0750'
  }

  if $manage_packages {
    package { $package_name:
      ensure => installed,
    }
    -> file { $log_dir:
      ensure => directory,
      owner  => $user,
      group  => $group,
      mode   => $mode,
    }
  }
}
