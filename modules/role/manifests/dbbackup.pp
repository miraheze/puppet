# class: role::dbbackup
class role::dbbackup {
    $clusters = lookup('role::dbbackup::clusters')
    $clusters.map |String $cluster| {
        motd::role { "role::dbbackup, cluster ${cluster}":
            description => "database replica (for backup) of cluster ${cluster}",
        }
    }

    # Dedicated account for database backup transfers
    users::user { 'dbbackup-user':
        ensure      => present,
        uid         => 3101,
        ssh_keys    => [
            'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILV8ZJLdefzSMcPe1o40Nw6TjXvt17JSpvxhIwZI0YcF'
        ],
    }

    class { 'dbbackup::storage':
        backup_dir      =>  '/srv/backups',
        clusters        =>  $clusters,
        backup_user     =>  'dbbackup-user',
        backup_group    =>  'dbbackup-user',
    }
}
