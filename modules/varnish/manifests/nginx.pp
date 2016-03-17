# class to handle Varnish nginx (using heria coolness)
class varnish::nginx {
    $sslcerts = hiera_hash('ssl')

    nginx::site { 'mediawiki':
        ensure  => present,
        content => template('varnish/mediawiki.conf'),
    }
}
