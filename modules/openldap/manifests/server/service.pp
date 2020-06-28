# See README.md for details.
class openldap::server::service {

  if ! defined(Class['openldap::server']) {
    fail 'class ::openldap::server has not been evaluated'
  }

  $ensure = $::openldap::server::start ? {
    true    => running,
    default => stopped,
  }

  $provider = 'debian'

  service { $::openldap::server::service:
    ensure    => $ensure,
    provider  => $provider,
    enable    => $::openldap::server::enable,
    hasstatus => $::openldap::server::service_hasstatus,
  }
}
