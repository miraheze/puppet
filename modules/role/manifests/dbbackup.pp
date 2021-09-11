# class: role::dbbackup
class role::dbbackup {
    $clusters = lookup('role::dbbackup::clusters')
    $clusters.map |String $cluster| {
        motd::role { "role::dbbackup, cluster ${cluster}":
            description => "database replica (for backup) of cluster ${cluster}",
        }
    }

    # Dedicated account for database backup transfers
    # dbbackup-user uid/gid/group must be equal on servers
    users::group { 'dbbackup-user':
        ensure  => present,
        gid     => 3201,
    } ->
    users::user { 'dbbackup-user':
        ensure      => present,
        uid         => 3201,
        gid         => 3201,
        ssh_keys    => [
            'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILV8ZJLdefzSMcPe1o40Nw6TjXvt17JSpvxhIwZI0YcF'
        ],
    } ->
    file { '/home/dbbackup-user/.ssh':
        ensure  => directory,
        owner   => 'dbbackup-user',
        group   => 'dbbackup-user',
        mode    => '0700',
    } ->
    file { '/home/dbbackup-user/.ssh/id_ed25519':
        ensure      => present,
        source      => 'puppet:///private/dbbackup/dbbackup-user.id_ed25519',
        owner       => 'dbbackup-user',
        group       => 'dbbackup-user',
        mode        => '0400',
        show_diff   => false,
    }

    file { '/srv/backups':
        ensure  => directory,
        owner   => 'dbbackup-user',
        group   => 'dbbackup-user',
        mode    => '0750',
        require => Users::User['dbbackup-user'],
    } ->
    class { 'dbbackup::storage':
        backup_dir      =>  '/srv/backups',
        clusters        =>  $clusters,
        backup_user     =>  'dbbackup-user',
        backup_group    =>  'dbbackup-user',
    }
}
