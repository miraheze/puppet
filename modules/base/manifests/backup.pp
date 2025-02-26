# class base::backup
class base::backup (
    String $pca_password = lookup('private::passwords::pca'),
    String $pca_legacy_password = lookup('private::passwords::legacy_pca'),
    Boolean $use_gateway = lookup('use_gateway', {'default_value' => true}),
) {
    package { ['python3-fabric', 'python3-decorator']:
        ensure => present,
    }

    file { '/usr/local/bin/wikitide-backup':
        mode    => '0555',
        content => template('base/backups/wikitide-backup.py.erb'),
    }

    file { '/usr/local/bin/wikitide-backup-legacy':
        mode    => '0555',
        content => template('base/backups/wikitide-backup-legacy.py.erb'),
    }
}
