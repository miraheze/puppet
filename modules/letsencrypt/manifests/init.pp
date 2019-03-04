# class: letsencrypt
class letsencrypt (
    $username = hiera('letsencrypt_rest_api_username', undef),
    $password = hiera('letsencrypt_rest_api_password', undef),
) {
    include ::apt

    apt::pin { 'certbot_backports':
        priority   => 740,
        originator => 'Debian',
        release    => 'stretch-backports',
        packages   => 'certbot',
    }

    package { 'certbot':
        ensure  => installed,
        require => Apt::Pin['certbot_backports'],
    }

    file { '/etc/letsencrypt':
        ensure  => 'link',
        force   => true,
        target  => '/mnt/mediawiki-static/private/miraheze/letsencrypt',
        require => Package['certbot'],
    }

    file { '/etc/letsencrypt/cli.ini':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/letsencrypt/cli.ini',
        mode    => '0644',
        require => File['/etc/letsencrypt']
    }

    ['/mnt/mediawiki-static/private/miraheze/.well-known', '/mnt/mediawiki-static/private/miraheze/.well-known/acme-challenge'].each |$folder| {
        file { "${folder}":
            ensure => directory,
            owner  => 'root',
            group  => 'root',
            mode   => '0755',
        }
    }

    file { '/var/www/.well-known':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    file { '/var/www/.well-known/acme-challenge':
        ensure  => 'link',
        force   => true,
        target  => '/mnt/mediawiki-static/private/miraheze/.well-known/acme-challenge',
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        require => File['/var/www/.well-known'],
    }

    file { '/root/ssl':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0770',
    }

    file { '/root/ssl-certificate':
        ensure => present,
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/letsencrypt/ssl-certificate.py',
        mode   => '0775',
    }

    class { 'letsencrypt::web':
        username => $username,
        password => $password,
    }
}
