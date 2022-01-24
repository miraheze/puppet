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
        ssh_keys => [
            'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDktIRXHBi4hDZvb6tBrPZ0Ag6TxLbXoQ7CkisQqOY6V MediaWikiDeploy'
        ],
    }

    file { '/var/www/.ssh':
        ensure => directory,
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0400',
    }

    file { '/var/www/.ssh/authorized_keys':
        ensure => file,
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0400',
    }
}
