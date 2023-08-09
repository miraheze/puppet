# Class for loading all certificates.
class ssl::all_certs {
    if defined(Service['nginx']) {
        $restart_nginx = Service['nginx']
    } else {
        $restart_nginx = undef
    }

    file { '/etc/ssl/localcerts':
        ensure  => directory,
        source  => 'puppet:///ssl/certificates',
        recurse => remote,
        purge   => true,
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
        notify    => $restart_nginx,
    }
}
