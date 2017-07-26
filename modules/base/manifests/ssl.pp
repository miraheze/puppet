# base::ssl
class base::ssl {
    file { 'authority certificates':
        path    => '/etc/ssl/certs',
        source  => 'puppet:///ssl/ca/',
        recurse => 'remote',
    }
}
