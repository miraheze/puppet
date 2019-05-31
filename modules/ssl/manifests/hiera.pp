# class for auto loading SSL certs onto machines needing them
class ssl::hiera {
    $ssldomains = loadyaml('/etc/puppet/ssl/certs.yaml')
    $sslredirects = loadyaml('/etc/puppet/ssl/redirects.yaml')

    $certs = merge( $ssldomains, $sslredirects )

    # resource handler to create certs via a definied type and hash
    create_resources('ssl::hiera::certs', $certs)
}
