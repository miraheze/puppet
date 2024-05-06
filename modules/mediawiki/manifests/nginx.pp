# === Class mediawiki::nginx
#
# Nginx config using hiera
class mediawiki::nginx {
    $sslcerts = loadyaml('/etc/puppetlabs/puppet/ssl-cert/certs.yaml')
    $sslredirects = loadyaml('/etc/puppetlabs/puppet/ssl-cert/redirects.yaml')
    $php_fpm_sock = 'php/fpm-www.sock'

    $module_path = get_module_path($module_name)
    $csp = loadyaml("${module_path}/data/csp.yaml")

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
