# === Class letsencrypt::nginx
#
# Nginx config using hiera
class letsencrypt::nginx {
    $sslcerts = loadyaml('/etc/puppetlabs/puppet/ssl-cert/certs.yaml')

    nginx::site { 'letsencrypt':
        ensure  => present,
        source  => 'puppet:///modules/letsencrypt/nginx.conf',
        monitor => false,
    }

    ssl::wildcard { 'letsencrypt nginx wildcard': }

    include ssl::hiera
}
