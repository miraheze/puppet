# === Class ssl::nginx
#
# Nginx config using hiera
class ssl::nginx {
    $sslcerts = loadyaml('/etc/puppetlabs/puppet/ssl-cert/certs.yaml')

    nginx::site { 'ssl':
        ensure  => present,
        source  => 'puppet:///modules/ssl/nginx.conf',
        monitor => false,
    }

    sslcert::wildcard { 'ssl nginx wildcard': }

    include sslcert::hiera
}
