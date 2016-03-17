# class for auto loading SSL certs onto machines needing them
class ssl::hiera {
    $certs = hiera_hash('ssl')

    # resource handler to create certs via a definied type and hash
    create_resources('ssl::hiera::certs', $certs)
}
