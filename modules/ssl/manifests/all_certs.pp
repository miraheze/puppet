# Class for loading all certificates.
class ssl::all_certs {
    # For now, assume nginx service is always defined; the function seems to be always returning false
    # We only load this class from nginx definitions anyway
    #if defined(Service['nginx']) {
    $restart_nginx = Service['nginx']
    #} else {
    #    $restart_nginx = undef
    #}

    file { '/etc/ssl/localcerts':
        ensure  => directory,
        owner   => 'root',
        group   => 'ssl-cert',
        source  => 'puppet:///ssl/certificates',
        mode    => '0775',
        recurse => remote,
        purge   => true,
        ignore  => [
            # TODO: Move to seperate directory to allow us
            # to not use this hack.
            'opensearch-admin-cert.pem',
            'opensearch-node.crt'
        ],
        notify  => $restart_nginx,
    }

    file { '/etc/ssl/private':
        ensure    => directory,
        source    => 'puppet:///ssl-keys',
        owner     => 'root',
        group     => 'ssl-cert',
        mode      => '0660',
        show_diff => false,
        recurse   => remote,
        purge     => true,
        ignore    => [
            '.git',
            # TODO: Move to seperate directory to allow us
            # to not use this hack.
            'opensearch-admin-key.pem',
            'opensearch-node-key.pem'
        ],
        notify    => $restart_nginx,
    }
}
