# class to handle Varnish nginx (using hiera coolness)
class varnish::nginx {

    file { '/etc/nginx/sites-enabled/default':
        ensure => absent,
        notify => Service['nginx'],
    }

    $sslcerts = loadyaml('/etc/puppetlabs/puppet/ssl-cert/certs.yaml')
    $sslredirects = loadyaml('/etc/puppetlabs/puppet/ssl-cert/redirects.yaml')

    nginx::site { 'mediawiki':
        ensure  => present,
        content => template('varnish/mediawiki.conf'),
    }

    include ssl::all_certs
}
