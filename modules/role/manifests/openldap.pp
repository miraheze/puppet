# = Class: role::openldap
#
# Sets up OpenLDAP
#
# = Parameters
#
class role::openldap (
    String $admin_password = lookup('profile::openldap::admin_password'),
    String $ldapvi_password = lookup('profile::openldap::ldapvi_password'),
    String $ldap_host = lookup('profile::openldap::ldap_host', {'default_value' => $facts['networking']['fqdn']}),
) {

    class { 'openldap::server':
        ldaps_ifs => ['/'],
        ssl_ca    => '/etc/ssl/certs/ISRG_Root_X1.pem',
        ssl_cert  => '/etc/ssl/localcerts/wikitide.net.crt',
        ssl_key   => '/etc/ssl/private/wikitide.net.key',
        require   => Ssl::Wildcard['openldap wildcard']
    }

    openldap::server::database { 'dc=miraheze,dc=org':
        ensure    => present,
        directory => '/var/lib/ldap/miraheze',
        rootdn    => 'cn=admin,dc=miraheze,dc=org',
        rootpw    => $admin_password,
    }

    # LDAP monitoring support
    openldap::server::database { 'cn=monitor':
        ensure  => present,
        backend => 'monitor',
    }

    # Allow everybody to try to bind
    openldap::server::access { '0 on dc=miraheze,dc=org':
        what   => 'attrs=userPassword,shadowLastChange',
        access => [
            'by dn="cn=admin,dc=miraheze,dc=org" write',
            'by group.exact="cn=Administrators,ou=groups,dc=miraheze,dc=org" write',
            'by self write',
            'by anonymous auth',
            'by * none',
        ],
    }

    # Allow admin users to manage things and authed users to read
    openldap::server::access { '1 on dc=miraheze,dc=org':
        what   => 'dn.children="dc=miraheze,dc=org"',
        access => [
            'by group.exact="cn=Administrators,ou=groups,dc=miraheze,dc=org" write',
            'by users read',
            'by * break',
        ],
    }

    openldap::server::access { '2 on cn=monitor':
        ensure => present,
        what   => 'dn.subtree="cn=monitor"',
        access => [
            'by dn="cn=admin,dc=miraheze,dc=org" write',
            'by dn="cn=monitor,dc=miraheze,dc=org" read',
            'by self write',
            'by * none',
        ],
    }

    # Modules
    openldap::server::module { 'back_mdb':
        ensure => present,
    }

    openldap::server::module { 'back_monitor':
        ensure => present,
    }

    openldap::server::module { 'memberof':
        ensure => present,
    }

    openldap::server::module { 'syncprov':
        ensure => present,
    }

    openldap::server::module { 'auditlog':
        ensure => present,
    }

    openldap::server::module { 'deref':
        ensure => present,
    }

    openldap::server::module { 'unique':
        ensure => present,
    }

    openldap::server::overlay { 'memberof on dc=miraheze,dc=org':
        ensure => present,
    }

    # Schema
    openldap::server::schema { 'core':
        ensure => present,
        path   => '/etc/ldap/schema/core.schema',
    }

    openldap::server::schema { 'cosine':
        ensure => present,
        path   => '/etc/ldap/schema/cosine.schema',
    }

    # openldap::server::schema { 'nis':
    #    ensure => present,
    #    path   => '/etc/ldap/schema/nis.ldif',
    # }

    openldap::server::schema { 'inetorgperson':
        ensure => present,
        path   => '/etc/ldap/schema/inetorgperson.schema',
    }

    openldap::server::schema { 'dyngroup':
        ensure => present,
        path   => '/etc/ldap/schema/dyngroup.schema',
    }

    file { '/etc/ldap/schema/postfix.schema':
        source => 'puppet:///modules/role/openldap/postfix.schema',
    }

    openldap::server::schema { 'postfix':
        ensure  => present,
        path    => '/etc/ldap/schema/postfix.schema',
        require => File['/etc/ldap/schema/postfix.schema'],
    }

    openldap::server::overlay { 'ppolicy':
        ensure  => present,
        suffix  => 'cn=config',
        overlay => 'ppolicy',
        options => {
            'olcPPolicyHashCleartext' => 'TRUE',
        },
    }

    class { 'openldap::client':
        base       => 'dc=miraheze,dc=org',
        uri        => ["ldaps://${facts['networking']['fqdn']}"],
        tls_cacert => '/etc/ssl/certs/ISRG_Root_X1.pem',
    }

    ssl::wildcard { 'openldap wildcard':
        notify_service => Service['slapd']
    }

    include prometheus::exporter::openldap

    stdlib::ensure_packages('ldapvi')

    file { '/etc/ldapvi.conf':
        content => template('role/openldap/ldapvi.conf.erb'),
        mode    => '0440',
        owner   => 'root',
        group   => 'root',
    }

    file { '/usr/local/bin/modify-ldap-group':
        source => 'puppet:///modules/role/openldap/modify-ldap-group',
        mode   => '0550',
        owner  => 'root',
        group  => 'root',
    }

    file { '/usr/local/bin/modify-ldap-user':
        source => 'puppet:///modules/role/openldap/modify-ldap-user',
        mode   => '0550',
        owner  => 'root',
        group  => 'root',
    }

    $firewall_rules = join(
        query_facts('Class[Role::Grafana] or Class[Role::Graylog] or Class[Role::Llm] or Class[Role::Matomo] or Class[Role::Mediawiki] or Class[Role::Mediawiki_task] or Class[Role::Mediawiki_beta] or Class[Role::Openldap]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
            }
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'ldaps':
        proto  => 'tcp',
        port   => '636',
        srange => "(${firewall_rules})",
    }
    $firewall_rules_icinga = join(
        query_facts('Class[Role::Icinga2]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
            }
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'ldap':
        proto  => 'tcp',
        port   => '389',
        srange => "(${firewall_rules_icinga})",
    }

    file { '/usr/local/sbin/restart_openldap':
        source => 'puppet:///modules/openldap/restart_openldap.sh',
        mode   => '0554',
        owner  => 'root',
        group  => 'root',
    }

    $minutes = fqdn_rand(60, $title)
    systemd::timer::job { 'restart_slapd':
        ensure      => present,
        user        => 'root',
        description => 'Restart slapd when using more than 50% of memory',
        command     => '/usr/local/sbin/restart_openldap',
        interval    => {
            start    => 'OnCalendar',
            interval => "*-*-* *:0/${minutes}:00",
        },
    }

    monitoring::services { 'LDAP':
        check_command => 'ldap',
        vars          => {
            ldap_address => $facts['networking']['fqdn'],
            ldap_base    => 'dc=miraheze,dc=org',
            ldap_v3      => true,
        },
    }

    monitoring::nrpe { 'LDAP SSL check':
        command => '/usr/lib/nagios/plugins/check_tcp -H localhost -p 636 -D 7,3',
    }

    system::role { 'openldap':
        description => 'LDAP server',
    }
}
