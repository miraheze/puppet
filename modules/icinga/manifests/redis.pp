# @summary
#   Base class for all redis owned by Icinga.
#
class icinga::redis {
  class { 'redis':
    manage_repo     => false,
    manage_package  => false,
    default_install => false,
    ulimit_managed  => false,
    service_manage  => false,
    config_owner    => 'root',
    config_group    => 'root',
    service_user    => 'root',
    service_group   => 'root',
  }
  contain redis
}
