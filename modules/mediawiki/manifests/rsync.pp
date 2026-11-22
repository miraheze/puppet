# === Class mediawiki::rsync
#
# MediaWiki remote sync configuration
class mediawiki::rsync {
    users::user { 'www-data':
        ensure   => present,
        uid      => 33,
        gid      => 33,
        system   => true,
        homedir  => '/var/www',
        shell    => '/bin/bash',
        before   => Service['nginx'],
        ssh_keys => [],
    }

    file { '/var/www/.ssh':
        ensure  => absent,
        require => File['/var/www'],
    }

    file { '/var/www/.ssh/authorized_keys':
        ensure  => absent,
        require => File['/var/www/.ssh'],
    }
}
