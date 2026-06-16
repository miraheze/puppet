# @summary
#   Installs IcingaDB
#
# @api private
#
class icingadb::install {
  assert_private()

  $package_name    = $icingadb::globals::package_name
  $manage_packages = $icingadb::manage_packages

  if $manage_packages {
    package { $package_name:
      ensure => installed,
    }
  }
}
