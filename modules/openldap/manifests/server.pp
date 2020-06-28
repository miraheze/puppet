# See README.md for details.
class openldap::server(
  $package                                 = $openldap::params::server_package,
  $confdir                                 = $openldap::params::server_confdir,
  $conffile                                = $openldap::params::server_conffile,
  $service                                 = $openldap::params::server_service,
  $service_hasstatus                       = $openldap::params::server_service_hasstatus,
  $owner                                   = $openldap::params::server_owner,
  $group                                   = $openldap::params::server_group,
  $enable                                  = true,
  $start                                   = true,
  $provider                                = 'olc',
  Optional[Stdlib::Absolutepath] $ssl_key  = undef,
  Optional[Stdlib::Absolutepath] $ssl_cert = undef,
  Optional[Stdlib::Absolutepath] $ssl_ca   = undef,
  Hash $databases                          = {},
  $ldap_ifs                                = ['/'],
  $ldaps_ifs                               = [],
  $ldapi_ifs                               = ['/'],
) inherits ::openldap::params {

  class { '::openldap::server::install': }
  -> class { '::openldap::server::config': }
  ~> class { '::openldap::server::service': }

  class { '::openldap::server::slapdconf': }

  case $provider {
    'augeas': {
      Class['openldap::server::install']
      -> Class['openldap::server::slapdconf']
      ~> Class['openldap::server::service']
      -> Class['openldap::server']
    }
    'olc': {
      Class['openldap::server::service']
      -> Class['openldap::server::slapdconf']
      -> Class['openldap::server']
    }
    default: {
      fail 'provider must be one of "olc" or "augeas"'
    }
  }
}
