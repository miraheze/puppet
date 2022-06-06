# === Class acme::nginx
#
# Nginx config using hiera
class acme::nginx {
    $sslcerts = loadyaml('/etc/puppetlabs/puppet/ssl-cert/certs.yaml')

    nginx::site { 'acme':
        ensure  => present,
        source  => 'puppet:///modules/acme/nginx.conf',
        monitor => false,
    }

    sslcert::wildcard { 'acme nginx wildcard': }

    include sslcert::hiera
}
