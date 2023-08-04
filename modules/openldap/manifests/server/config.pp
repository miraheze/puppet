# See README.md for details.
class openldap::server::config {

  if ! defined(Class['openldap::server']) {
    fail 'class ::openldap::server has not been evaluated'
  }

  $slapd_ldap_ifs = empty($::openldap::server::ldap_ifs) ? {
    false => join(prefix($::openldap::server::ldap_ifs, 'ldap://'), ' '),
    true  => '',
  }
  $escaped_ldapi_ifs = $::openldap::server::escape_ldapi_ifs ? {
    true  => regsubst($::openldap::server::ldapi_ifs, '/', '%2F', 'G'),
    false => $::openldap::server::ldapi_ifs,
  }
  $slapd_ldapi_ifs = empty($::openldap::server::ldapi_ifs) ? {
    false => join(prefix($escaped_ldapi_ifs, 'ldapi://'), ' '),
    true  => '',
  }
  $slapd_ldaps_ifs = empty($::openldap::server::ldaps_ifs) ? {
    false  => join(prefix($::openldap::server::ldaps_ifs, 'ldaps://'), ' '),
    true => '',
  }
  $slapd_ldap_urls = "${slapd_ldap_ifs} ${slapd_ldapi_ifs} ${slapd_ldaps_ifs}"

  case $facts['os']['family'] {
    'Debian': {
      shellvar { 'slapd':
        ensure   => present,
        target   => '/etc/default/slapd',
        variable => 'SLAPD_SERVICES',
        value    => $slapd_ldap_urls,
      }
    }
    'RedHat': {
      if versioncmp($::operatingsystemmajrelease, '6') <= 0 {
        $ldap = empty($::openldap::server::ldap_ifs) ? {
          false => 'yes',
          true  => 'no',
        }
        shellvar { 'SLAPD_LDAP':
          ensure   => present,
          target   => '/etc/sysconfig/ldap',
          variable => 'SLAPD_LDAP',
          value    => $ldap,
        }
        $ldaps = empty($::openldap::server::ldaps_ifs) ? {
          false => 'yes',
          true  => 'no',
        }
        shellvar { 'SLAPD_LDAPS':
          ensure   => present,
          target   => '/etc/sysconfig/ldap',
          variable => 'SLAPD_LDAPS',
          value    => $ldaps,
        }
        $ldapi = empty($::openldap::server::ldapi_ifs) ? {
          false => 'yes',
          true  => 'no',
        }
        shellvar { 'SLAPD_LDAPI':
          ensure   => present,
          target   => '/etc/sysconfig/ldap',
          variable => 'SLAPD_LDAPI',
          value    => $ldapi,
        }
      } else {
        shellvar { 'slapd':
          ensure   => present,
          target   => '/etc/sysconfig/slapd',
          variable => 'SLAPD_URLS',
          value    => $slapd_ldap_urls,
        }
      }
    }
    'Archlinux': {}
    'FreeBSD': {
      shellvar { 'slapd_cn_config':
        ensure   => present,
        target   => '/etc/rc.conf',
        variable => 'slapd_cn_config',
        value    => bool2str($openldap::server::provider == 'olc', 'YES', 'NO'),
        quoted   => 'double',
      }

      shellvar { 'slapd_flags':
        ensure   => present,
        target   => '/etc/rc.conf',
        variable => 'slapd_flags',
        value    => "-h '${slapd_ldap_urls}'",
        quoted   => 'double',
      }

      shellvar { 'slapd_sockets':
        ensure   => present,
        target   => '/etc/rc.conf',
        variable => 'slapd_sockets',
        value    => join($::openldap::server::ldapi_ifs, ' '),
        quoted   => 'double',
      }
    }
    default: {
      fail "Operating System Family ${facts['os']['family']} not yet supported"
    }
  }
}
