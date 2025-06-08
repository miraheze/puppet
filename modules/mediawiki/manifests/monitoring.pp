# === Class mediawiki::monitoring
class mediawiki::monitoring {

    # Admin interface (and prometheus metrics) for APCu and opcache
    file { '/var/www/php-monitoring':
        ensure  => directory,
        recurse => true,
        owner   => 'root',
        group   => 'www-data',
        mode    => '0555',
        source  => 'puppet:///modules/mediawiki/php/admin'
    }

    nginx::site { 'php-admin':
        ensure  => present,
        content => template('mediawiki/php-admin.conf.erb'),
    }

    ## Admin script
    file { '/usr/local/bin/php8adm':
        ensure => present,
        source => 'puppet:///modules/mediawiki/php/php8adm.sh',
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
    }

    monitoring::services { 'MediaWiki Rendering':
        check_command => 'check_mediawiki',
        docs          => 'https://meta.miraheze.org/wiki/Tech:Icinga/MediaWiki_Monitoring#MediaWiki_Rendering',
        vars          => {
            host    => lookup('mediawiki::monitoring::host'),
            address => $facts['networking']['ip'],
        },
    }

    monitoring::services { 'HTTPS':
        check_command => 'check_curl',
        vars          => {
            address          => $facts['networking']['ip'],
            http_vhost       => $facts['networking']['fqdn'],
            http_ssl         => true,
            http_ignore_body => true,
            http_expect      => 'HTTP/2 200',
        },
    }
}
