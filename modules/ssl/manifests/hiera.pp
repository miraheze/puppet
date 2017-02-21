# class for auto loading SSL certs onto machines needing them
class ssl::hiera {
    $ssldomains = hiera_hash('ssl')
    $sslredirects = hiera_hash('redirects')

    $certs = merge( $ssldomains, $sslredirects )

    # resource handler to create certs via a definied type and hash
    create_resources('ssl::hiera::certs', $certs)
}
