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
        ensure  => directory,
        owner   => 'www-data',
        group   => 'www-data',
        mode    => '0400',
        require => File['/var/www'],
    }

    file { '/var/www/.ssh/authorized_keys':
        ensure  => file,
        owner   => 'www-data',
        group   => 'www-data',
        mode    => '0400',
        require => File['/var/www/.ssh'],
    }
}
