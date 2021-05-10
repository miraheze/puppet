# class: dbbackup::dumper
class dbbackup::dumper(
    String  $mount_host                 = undef,
    String  $mount_user                 = undef,
    String  $mount_group                = undef,
    String  $mount_ssh_key_file         = undef,
    String  $mount_local_dir_prefix     = undef,
    String  $mount_remote_dir_prefix    = undef,
    Array   $mount_clusters             = [],
) {
    # credit: https://github.com/wwkimball/wwkimball-sshfs/blob/master/manifests/client/mount.pp

    ensure_packages(['sshfs'])

    $mount_clusters.each |String $clusterName| {
        file {
            ensure  => directory,
            owner   => $mount_user,
            group   => $mount_group,
            mode    => '0750',
        } ->
        mount { "${mount_dir_prefix}${clusterName}":
            ensure      => mounted,
            atboot      => true,
            device      => "${mount_user}@${mount_host}:${mount_remote_dir_prefix}${clusterName}",
            dump        => 0,
            fstype      => 'fuse.sshfs',
            options     => "StrictHostKeyChecking=yes,IdentityFile=${mount_ssh_key_file}",
            pass        => 0,
            remounts    => false,
        }
    }
}
