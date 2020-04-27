# See README.md for details.
class openldap::params {
  $client_package           = 'libldap-2.4-2'
  $client_conffile          = '/etc/ldap/ldap.conf'
  $server_confdir           = '/etc/ldap/slapd.d'
  $server_conffile          = '/etc/ldap/slapd.conf'
  $server_group             = 'openldap'
  $server_owner             = 'openldap'
  $server_package           = 'slapd'
  $server_service           = 'slapd'
  $server_service_hasstatus = true
  $utils_package            = 'ldap-utils'
}
