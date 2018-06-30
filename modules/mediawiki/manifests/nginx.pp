# MediaWiki nginx config using hiera
class mediawiki::nginx {

    $sslcerts = loadyaml('/etc/puppet/ssl/certs.yaml')
    
    $use_swift = hiera('use_swift', false)

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

    file { '/etc/nginx/nginx.conf':
        content => template('mediawiki/nginx.conf.erb'),
        require => Package['nginx'],
    }

    file { '/etc/nginx/fastcgi_params':
        ensure => present,
        source => 'puppet:///modules/mediawiki/nginx/fastcgi_params',
    }

    file { '/etc/nginx/sites-enabled/default':
        ensure => absent,
    }

    include ssl::wildcard
    include ssl::hiera

    if hiera('mediawiki::use_php_7_2', false) {
        $php_fpm_sock = 'php/php7.2-fpm.sock'
    } else {
        $php_fpm_sock = 'php/php7.0-fpm.sock'
    }

    nginx::conf { 'mediawiki-includes':
        ensure => present,
        content => template('mediawiki/mediawiki-includes.conf.erb'),
    }
}
