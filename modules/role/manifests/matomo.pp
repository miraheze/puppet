# role: matomo
class role::matomo {
    include ::matomo

    if !defined(Ferm::Service['http']) {
        ferm::service { 'http':
            proto => 'tcp',
            port  => '80',
        }
    }

    if !defined(Ferm::Service['https']) {
        ferm::service { 'https':
            proto => 'tcp',
            port  => '443',
        }
    }

    motd::role { 'role::matomo':
        description => 'central analytics server',
    }
}
