# class: nodejs
class nodejs {
    include ::apt

    apt::source { 'nodejs_apt':
        comment  => 'NODEJS',
        location => 'https://deb.nodesource.com/node_8.x',
        release  => "${::lsbdistcodename}",
        repos    => 'main',
        key      => '9FD3B784BC1C6FC31A8A0A1C1655A0AB68576280',
        notify   => Exec['apt_update_nodejs'],
    }
 
    # First installs can trip without this
    exec {'apt_update_nodejs':
        command     => '/usr/bin/apt-get update',
        refreshonly => true,
        logoutput   => true,
    }

    require_package('nodejs')
}
