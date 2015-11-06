class role::parsoid {
    include ::parsoid

    ufw::allow { 'parsoid':
        proto => 'tcp',
        port  => 8142,
        from  => '185.52.1.75',
    }

    ufw::allow { 'parsoid monitoring':
        proto => 'tcp',
        port  => 8142,
        from  => '185.52.1.76',
    }

    motd::role { 'role::parsoid':
        description => 'parsoid server',
    }
}
