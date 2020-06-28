# See README.md for details.
class openldap::client(
  $package                                      = $openldap::params::client_package,
  $file                                         = $openldap::params::client_conffile,

  # Options
  $base                                         = undef,
  $bind_policy                                  = undef,
  $bind_timelimit                               = undef,
  $binddn                                       = undef,
  $bindpw                                       = undef,
  $ldap_version                                 = undef,
  $network_timeout                              = undef,
  $scope                                        = undef,
  $ssl                                          = undef,
  $suffix                                       = undef,
  $timelimit                                    = undef,
  $timeout                                      = undef,
  $uri                                          = undef,

  # NSS Options
  $nss_base_group                               = undef,
  $nss_base_hosts                               = undef,
  $nss_base_passwd                              = undef,
  $nss_base_shadow                              = undef,
  $nss_initgroups_ignoreusers                   = undef,

  # PAM Options
  $pam_filter                                   = undef,
  $pam_login_attribute                          = undef,
  $pam_member_attribute                         = undef,
  $pam_password                                 = undef,

  # TLS Options
  Optional[Stdlib::Absolutepath] $tls_cacert    = undef,
  Optional[Stdlib::Absolutepath] $tls_cacertdir = undef,
  $tls_checkpeer                                = undef,
  $tls_reqcert                                  = undef,

  # SASL Options
  $sasl_mech            = undef,
  $sasl_realm           = undef,
  $sasl_authcid         = undef,
  $sasl_secprops        = undef,
  $sasl_nocanon         = undef,

  # GSSAPI Options
  $gssapi_sign                   = undef,
  $gssapi_encrypt                = undef,
  $gssapi_allow_remote_principal = undef,

  # SUDO Options
  $sudoers_base                                 = undef,
) inherits ::openldap::params {
  anchor { 'openldap::client::begin': }
  -> class { '::openldap::client::install': }
  -> class { '::openldap::client::config': }
  -> anchor { 'openldap::client::end': }
}
