# === Class ssl::nginx
#
# Nginx config using hiera
class ssl::nginx {
    nginx::site { 'ssl-acme':
        ensure  => present,
        source  => 'puppet:///modules/ssl/nginx.conf',
        monitor => false,
    }

    ssl::wildcard { 'ssl-acme nginx wildcard': }
}
