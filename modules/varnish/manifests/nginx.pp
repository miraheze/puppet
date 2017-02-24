# class to handle Varnish nginx (using hiera coolness)
class varnish::nginx {
    $sslcerts = hiera_hash('ssl')
    $sslredirects = hiera_hash('redirects')

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
        command => '/usr/sbin/service nginx reload',
    }
}
