# role: puppetserver
class role::puppetserver {
    motd::role { 'role::puppetserver':
        description => 'Central puppet server',
    }

    include ::profile::puppetserver
}
