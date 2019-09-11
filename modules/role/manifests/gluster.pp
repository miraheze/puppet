# role: gluster
class role::gluster {
    include ::gluster

    motd::role { 'role::gluster':
        description => 'A network file storage.',
    }
}
