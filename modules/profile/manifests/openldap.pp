# openldap server
class profile::openldap (
    String $password = lookup('profile::openldap::password'),
) {
    include ssl::wildcard

    class { 'openldap::server':
        ldaps_ifs => ['/'],
        ssl_ca    => '/etc/ssl/certs/Sectigo.crt',
        ssl_cert  => '/etc/ssl/certs/wildcard.miraheze.org.crt',
        ssl_key   => '/etc/ssl/private/wildcard.miraheze.org.key',
        require   => Class['ssl::wildcard'],
    }

    openldap::server::database { 'dc=miraheze,dc=org':
        directory => '/var/lib/ldap/miraheze',
        rootdn    => 'cn=admin,dc=miraheze,dc=org',
        rootpw    => $password,
    }

    # Allow everybody to try to bind
    openldap::server::access { '0 on dc=miraheze,dc=org':
        what     => 'attrs=userPassword,shadowLastChange',
        access   => [
            'by dn="cn=admin,dc=miraheze,dc=org" write',
            'by group.exact="cn=Administrators,ou=groups,dc=miraheze,dc=org" write',
            'by self write',
            'by anonymous auth',
            'by * none',
        ],
    }

    # Allow admin users to manage things and authed users to read
    openldap::server::access { '1 on dc=miraheze,dc=org':
        what     => 'dn.children="dc=miraheze,dc=org"',
        access   => [
            'by group.exact="cn=Administrators,ou=groups,dc=miraheze,dc=org" write',
            'by users read',
            'by * break',
        ],
    }

    # Modules
    openldap::server::module { 'back_mdb':
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

    openldap::server::module { 'ppolicy':
        ensure => present,
    }

    openldap::server::module { 'deref':
        ensure => present,
    }

    openldap::server::module { 'unique':
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

    openldap::server::schema { 'nis':
        ensure => present,
        path   => '/etc/ldap/schema/nis.ldif',
    }

    openldap::server::schema { 'inetorgperson':
        ensure => present,
        path   => '/etc/ldap/schema/inetorgperson.schema',
    }

    openldap::server::schema { 'dyngroup':
        ensure => present,
        path   => '/etc/ldap/schema/dyngroup.schema',
    }

    openldap::server::schema { 'ppolicy':
        ensure => present,
        path   => '/etc/ldap/schema/ppolicy.schema',
    }

    class { 'openldap::client':
        base       => 'dc=miraheze,dc=org',
        uri        => ["ldaps://${::fqdn}"],
        tls_cacert => '/etc/ssl/certs/Sectigo.crt',
    }

    require_package('ldapvi')

    file { '/etc/ldapvi.conf':
        content => template('profile/openldap/ldapvi.conf.erb'),
        mode    => '0440',
        owner   => 'root',
        group   => 'root',
    }

    file { '/usr/local/bin/modify-ldap-group':
        source => 'puppet:///modules/profile/openldap/modify-ldap-group',
        mode   => '0550',
        owner  => 'root',
        group  => 'root',
    }

    file { '/usr/local/bin/modify-ldap-user':
        source => 'puppet:///modules/profile/openldap/modify-ldap-user',
        mode   => '0550',
        owner  => 'root',
        group  => 'root',
    }


    $hostips = query_nodes("domain='$domain' and Class[Role::Grafana] or Class[Role::Matomo] or Class[Role::Openldap]", 'ipaddress')
    $hostips.each |$ip| {
        # Restrict access to ldap tls port
        ufw::allow { "ldaps port ${ip}":
            proto => 'tcp',
            port  => 636,
            from  => $ip,
        }
    }

    # TODO: Add monitoring for ldap

    # restart slapd if it uses more than 50% of memory (T130593)
    cron { 'restart_slapd':
        ensure  => present,
        minute  => fqdn_rand(60, $title),
        command => "/bin/ps -C slapd -o pmem= | awk '{sum+=\$1} END { if (sum <= 50.0) exit 1 }' \
        && /bin/systemctl restart slapd >/dev/null 2>/dev/null",
    }
}
