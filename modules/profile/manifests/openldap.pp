# openldap server
class profile::openldap (
    String $password = hiera('profile::openldap::password'),
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
        directory => '/var/lib/ldap',
        rootdn    => 'cn=admin,dc=miraheze,dc=org',
        rootpw    => $password,
    }

    openldap::server::module { 'memberof':
        ensure => present,
    }

    openldap::server::access { '0 on dc=miraheze,dc=org':
        what     => 'attrs=userPassword,shadowLastChange',
        access   => [
            'by dn="cn=admin,dc=miraheze,dc=org" write',
            'by anonymous auth',
            'by self write',
            'by * none',
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

    file { '/etc/ldap/schema/rfc2307bis.schema' :
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        source  => 'puppet:///modules/profile/openldap/rfc2307bis.schema',
        require => Class['openldap::server'],
    }

    openldap::server::schema { 'rfc2307bis':
        ensure  => present,
        path    => '/etc/ldap/schema/rfc2307bis.schema',
        require => File['/etc/ldap/schema/rfc2307bis.schema'],
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

    # only allow access to ldap tls port
    ufw::allow { 'ldaps port':
        proto => 'tcp',
        port  => 636,
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
