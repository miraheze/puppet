# MediaWiki nginx config using hiera
class mediawiki::nginx {

    $sslcerts = loadyaml('/etc/puppet/ssl/certs.yaml')

    nginx::site { 'mediawiki':
        ensure  => present,
        content => template('mediawiki/mediawiki.conf'),
        notify  => Exec['nginx-syntax'],
    }

    exec { 'nginx-syntax':
        command     => '/usr/sbin/nginx -t',
        notify      => Exec['nginx-reload'],
        refreshonly => true,
    }

    exec { 'nginx-reload':
        command     => '/usr/sbin/service nginx reload',
        refreshonly => true,
        require     => Exec['nginx-syntax'],
    }

    include ssl::wildcard
    include ssl::hiera

    $php_fpm_sock = 'php/php7.2-fpm.sock'

    nginx::conf { 'mediawiki-includes':
        ensure => present,
        content => template('mediawiki/mediawiki-includes.conf.erb'),
    }
}
