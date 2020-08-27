# MediaWiki nginx config using hiera
class mediawiki::nginx {

    $sslcerts = loadyaml('/etc/puppetlabs/puppet/ssl-cert/certs.yaml')
    $php_fpm_sock = 'php/fpm-www.sock'

    nginx::conf { 'mediawiki-includes':
        ensure => present,
        content => template('mediawiki/mediawiki-includes.conf.erb'),
    }

    nginx::site { 'mediawiki':
        ensure       => present,
        content      => template('mediawiki/mediawiki.conf.erb'),
        notify_site  => Exec['nginx-syntax'],
        require      => Nginx::Conf['mediawiki-includes'],
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

    Class['ssl::wildcard'] ~> Exec['nginx-syntax']
    Class['ssl::hiera'] ~> Exec['nginx-syntax']
}
