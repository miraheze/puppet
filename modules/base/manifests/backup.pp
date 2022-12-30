# class base::backup
class base::backup (
    String $pca_password = lookup('private::passwords::pca')
) {
    package { ['python3-fabric', 'python3-decorator']:
        ensure => present,
    }

    file { '/usr/local/bin/miraheze-backup':
        mode    => '0555',
        content => template('base/backups/miraheze-backup.py.erb'),
    }
}
