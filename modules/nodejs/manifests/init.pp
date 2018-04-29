# class: nodejs
class nodejs {
    include ::apt

    apt::source { 'nodejs_apt':
        comment  => 'NODEJS',
        location => 'https://deb.nodesource.com/node_8.x',
        release  => "${::lsbdistcodename}",
        repos    => 'main',
        key      => '9FD3B784BC1C6FC31A8A0A1C1655A0AB68576280',
    }

    require_package('nodejs')
}
