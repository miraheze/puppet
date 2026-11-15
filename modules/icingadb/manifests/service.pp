# @summary
#   Manage IcingaDB service
#
# @api private
#
class icingadb::service {
  assert_private()

  $service_name = $icingadb::globals::service_name
  $ensure       = $icingadb::ensure
  $enable       = $icingadb::enable

  service { $service_name:
    ensure => $ensure,
    enable => $enable,
  }
}
