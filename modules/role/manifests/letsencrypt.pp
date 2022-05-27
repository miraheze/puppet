# role: letsencrypt
class role::letsencrypt {
    include ::letsencrypt

    if !defined(Ferm::Service['http']) {
        ferm::service { 'http':
            proto   => 'tcp',
            port    => '80',
            notrack => true,
        }
    }

    if !defined(Ferm::Service['https']) {
        ferm::service { 'https':
            proto   => 'tcp',
            port    => '443',
            notrack => true,
        }
    }

    motd::role { 'role::letsencrypt':
        description => 'LetsEncrypt server',
    }
}
