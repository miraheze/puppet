# class for auto loading SSL certs onto machines needing them
class ssl::hiera {
    $ssldomains = loadyaml('/etc/puppetlabs/puppet/ssl-cert/certs.yaml')
    $sslredirects = loadyaml('/etc/puppetlabs/puppet/ssl-cert/redirects.yaml')

    $certs = merge( $ssldomains, $sslredirects )

    # resource handler to create certs via a definied type and hash
    create_resources('ssl::hiera::certs', $certs)
}
