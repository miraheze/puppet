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

    include ssl::wildcard

    nginx::site { 'ldapcherry.miraheze.org':
        ensure  => present,
        source  => 'puppet:///modules/profile/openldap/ldapcherry-nginx.conf',
        monitor => true,
    }

    # Note you will need to manually run `python3 setup.py install`
    # after git cloning. And also restart the ldapcherry service.
    git::clone { 'ldapcherry':
        directory          => '/srv/ldapcherry',
        origin             => 'https://github.com/kakwa/ldapcherry',
        branch             => '1.1.1', # Current stable
        recurse_submodules => true,
        owner              => 'www-data',
        group              => 'www-data',
        require            => Package['nginx']
    }

    file { '/var/lib/ldapcherry':
        ensure  => 'directory',
        owner   => 'www-data',
        group   => 'www-data',
        mode    => '2755',
        require => Package['nginx'],
    }

    file { '/var/lib/ldapcherry/sessions':
        ensure  => 'directory',
        owner   => 'www-data',
        group   => 'www-data',
        mode    => '2755',
        require => File['/var/lib/ldapcherry'],
    }

    file { '/etc/ldapcherry':
        ensure  => 'directory',
        owner   => 'www-data',
        group   => 'www-data',
        mode    => '2755',
        require => Package['nginx'],
    }

    file { '/etc/ldapcherry/ldapcherry.ini':
        ensure  => present,
        content => template('profile/openldap/ldapcherry.ini.erb'),
        owner   => 'www-data',
        group   => 'www-data',
        notify  => Service['ldapcherry'],
        require => File['/etc/ldapcherry'],
    }

    file { '/etc/ldapcherry/roles.yml':
        ensure  => present,
        source  => 'puppet:///modules/profile/openldap/roles.yml',
        owner   => 'www-data',
        group   => 'www-data',
        notify  => Service['ldapcherry'],
        require => File['/etc/ldapcherry'],
    }

    file { '/etc/ldapcherry/attributes.yml':
        ensure  => present,
        source  => 'puppet:///modules/profile/openldap/attributes.yml',
        owner   => 'www-data',
        group   => 'www-data',
        notify  => Service['ldapcherry'],
        require => File['/etc/ldapcherry'],
    }

    require_package('python3-setuptools')

    systemd::service { 'ldapcherry':
        ensure  => present,
        content => systemd_template('ldapcherry'),
        restart => true,
        require => Git::Clone['ldapcherry'],
    }

    # only allow access to ldap tls port
    ufw::allow { 'ldaps port':
        proto => 'tcp',
        port  => 636,
    }

    ufw::allow { 'http port tcp':
        proto => 'tcp',
        port  => 80,
    }

    $hostips = query_nodes("domain='$domain' and Class[Role::Grafana] OR Class[Role::Matomo] OR Class[Role::Ldapcherry]", 'ipaddress')
    $hostips.each |$ip| {
        ufw::allow { "https port tcp ${ip}":
            proto => 'tcp',
            port  => 443,
            from  => $key,
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

    cron { 'clean_sessions':
        ensure  => present,
        command => '/usr/bin/find /var/lib/ldapcherry/sessions -type f -mtime +2 -exec rm {} +',
        user    => 'root',
        hour    => 5,
        minute  => 0,
        require => File['/var/lib/ldapcherry/sessions'],
    }
}
