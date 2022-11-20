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
        ssh_keys => [
            'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFEak8evb6DAVAeYTl8Gyg0uCrcMAfPt9CUm++4NO8fb MediaWikiDeploy'
        ],
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
