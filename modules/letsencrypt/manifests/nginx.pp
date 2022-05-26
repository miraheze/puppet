# === Class letsencrypt::nginx
#
# Nginx config using hiera
class letsencrypt::nginx {
    $sslcerts = loadyaml('/etc/puppetlabs/puppet/ssl-cert/certs.yaml')
    $php_fpm_sock = 'php/fpm-www.sock'

    nginx::site { 'letsencrypt':
        ensure  => present,
        content => template('letsencrypt/nginx.conf.erb'),
    }

    ssl::wildcard { 'mediawiki nginx wildcard': }

    include ssl::hiera
}