# === Class mediawiki::nginx
#
# Nginx config using hiera
class mediawiki::nginx {
    $sslcerts = loadyaml('/etc/puppetlabs/puppet/ssl-cert/certs.yaml')
    $php_fpm_sock = 'php/fpm-www.sock'

    nginx::conf { 'mediawiki-includes':
        ensure  => present,
        content => template('mediawiki/mediawiki-includes.conf.erb'),
    }

    nginx::site { 'mediawiki':
        ensure  => present,
        content => template('mediawiki/mediawiki.conf.erb'),
        require => Nginx::Conf['mediawiki-includes'],
    }

    include ssl::all_certs
}
