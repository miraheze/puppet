# class to handle Varnish nginx (using hiera coolness)
class varnish::nginx {
    $sslcerts = loadyaml('/etc/puppet/ssl/certs.yaml')
    $sslredirects = loadyaml('/etc/puppet/ssl/redirects.yaml')

    nginx::site { 'mediawiki':
        ensure  => present,
        content => template('varnish/mediawiki.conf'),
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
}
