# role: roundcubemail
class role::roundcubemail {
    motd::role { 'roundcubemail':
        description => 'hosts our webmail client',
    }

    include ::profile::roundcubemail::main
}
