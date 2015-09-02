class role::parsoid {
    include ::parsoid

    ufw::allow { 'parsoid':
        proto => 'tcp',
        port  => 8142,
        from  => '185.52.1.75',
    }

    motd::role { 'role::parsoid':
        description => 'parsoid server',
    }
}
