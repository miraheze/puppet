# === Class ssl
class ssl {
    stdlib::ensure_packages('certbot')

    file { '/etc/letsencrypt/cli.ini':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/ssl/letsencrypt.ini',
        mode    => '0644',
        require => Package['certbot'],
    }

    ['/var/www', '/var/www/.well-known', '/var/www/.well-known/acme-challenge'].each |$folder| {
        file { $folder:
            ensure => directory,
            owner  => 'root',
            group  => 'root',
            mode   => '0755',
        }
    }

    file { '/var/www/challenges':
        ensure  => link,
        target  => '/var/www/.well-known/acme-challenge',
        require => File['/var/www/.well-known/acme-challenge'],
    }

    file { '/home/ssl-admins':
        ensure    => directory,
        owner     => 'puppet',
        group     => 'ssl-admins',
        mode      => '0660',
        recurse   => true,
        max_files => '7000',
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
        source => 'puppet:///modules/ssl/ssl-certificate.py',
        mode   => '0775',
    }

    file { '/srv/ssl':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0770',
    }

    file { '/srv/dns':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0770',
    }

    file { '/var/lib/nagios/ssl-acme':
        ensure => present,
        source => 'puppet:///modules/ssl/ssl-acme',
        owner  => 'root',
        group  => 'root',
        mode   => '0775',
    }

    file { '/var/lib/nagios/id_ed25519':
        ensure => present,
        source => 'puppet:///private/acme/id_ed25519',
        owner  => 'root',
        group  => 'root',
        mode   => '0400',
    }

    file { '/var/lib/nagios/id_ed25519.pub':
        ensure => present,
        source => 'puppet:///private/acme/id_ed25519.pub',
        owner  => 'root',
        group  => 'root',
        mode   => '0644',
    }

    git::clone { 'srv-ssl':
        ensure    => present,
        directory => '/srv/ssl/ssl',
        origin    => 'git@github.com:miraheze/ssl.git',
        ssh       => 'ssh -i /var/lib/nagios/id_ed25519 -F /dev/null -o ProxyCommand=\'nc -X connect -x bastion.fsslc.wtnet:8080 %h %p\'',
        require   => [
            File['/var/lib/nagios/id_ed25519'],
            File['/var/lib/nagios/id_ed25519.pub'],
            File['/srv/ssl'],
        ],
    }

    # We do not need to run the ssl renewal cron,
    # we run our own service.
    file { '/etc/cron.d/certbot':
        ensure  => absent,
        require => Package['certbot'],
    }

    service { 'certbot':
        ensure   => 'stopped',
        enable   => 'mask',
        provider => 'systemd',
        require  => Package['certbot'],
    }

    service { 'certbot.timer':
        ensure   => 'stopped',
        enable   => 'mask',
        provider => 'systemd',
        require  => Package['certbot'],
    }

    include ssl::web
}
