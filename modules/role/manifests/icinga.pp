class role::icinga {
    include ::icinga
    Include private::irc

    ufw::allow { 'icinga http':
        proto => 'tcp',
        port  => '80',
    }

    ufw::allow { 'icinga https':
        proto => 'tcp',
        port  => '443',
    }

    motd::role { 'role::icinga':
        description => 'central monitoring server',
    }
}
