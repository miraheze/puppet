# class to handle Varnish nginx (using hiera coolness)
class varnish::nginx {
    $sslcerts = loadyaml('/etc/puppetlabs/puppet/ssl-cert/certs.yaml')
    $sslredirects = loadyaml('/etc/puppetlabs/puppet/ssl-cert/redirects.yaml')

    # Used to whitelist miraheze ips within the rate limiter
    $ip_4 = query_nodes("domain='$domain'", 'ipaddress')
    $ip_6 = query_nodes("domain='$domain'", 'ipaddress6')

    nginx::site { 'mediawiki':
        ensure  => present,
        content => template('varnish/mediawiki.conf'),
    }
}
