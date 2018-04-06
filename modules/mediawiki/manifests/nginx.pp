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

    $php_version = os_version('debian >= stretch')

    nginx::conf { 'mediawiki-includes':
        ensure => present,
        content => template('mediawiki/mediawiki-includes.conf.erb'),
    }
}
