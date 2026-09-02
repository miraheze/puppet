class backup {
    stdlib::ensure_packages(['awscli', 'python3-fabric', 'python3-decorator'])

    $aws_access_key = lookup('private::passwords::backup::aws_access_key')
    $aws_secret_key = lookup('private::passwords::backup::aws_secret_key')

    file { '/etc/wikitide-backup':
        ensure => directory,
    }

    file { '/etc/wikitide-backup/aws-credentials':
        mode    => '0600',
        content => epp('backup/aws-credentials.epp', {
            'aws_access_key' => $aws_access_key,
            'aws_secret_key' => $aws_secret_key,
        }),
        require => File['/etc/wikitide-backup']
    }

    file { '/etc/wikitide-backup/aws-config':
        mode    => '0600',
        content => epp('backup/aws-config.epp'),
        require => File['/etc/wikitide-backup']
    }

    file { '/etc/wikitide-backup/lifecycle.json':
        mode    => '0600',
        source  => 'puppet:///modules/backup/lifecycle.json'
        require => File['/etc/wikitide-backup']
    }

    file { '/usr/local/bin/wikitide-backup':
        mode    => '0555',
        content => epp('backup/wikitide-backup.py.epp', {
            'use_gateway'  => $use_gateway,
            'pca_password' => $pca_password,
        }),
    }

    file { '/srv/backups':
        ensure => directory,
    }
}
