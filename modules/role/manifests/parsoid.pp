class role::parsoid {
    include ::parsoid

    ufw::allow { 'parsoid':
        proto => 'tcp',
        port => 8142,
    }

    motd::role { 'role::parsoid':
        description => 'parsoid server',
    }
}
