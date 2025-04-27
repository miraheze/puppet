# base::ssl
class base::ssl {
    stdlib::ensure_packages([
        'openssl',
        'ssl-cert',
        'ca-certificates',
    ])
}
