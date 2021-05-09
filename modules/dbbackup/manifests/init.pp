# class: dbbackup
class dbbackup(
    Optional[String]    $backup_dir     = '/srv/backups',
    Array               $clusters       = [],
    String              $backup_user    = undef,
    String              $backup_group   = undef,
) {
    $clusters.each |String $cluster| {
        file { "${backup_dir}/${cluster}":
            ensure  => directory,
            owner   => $backup_user,
            group   => $backup_group,
            mode    => '0640',
        }
    }
}
