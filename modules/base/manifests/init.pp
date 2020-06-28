# class: base
class base {
    include apt
    include base::packages
    include base::puppet
    include base::rsyslog
    include base::ssl
    include base::sysctl
    include base::timezone
    include base::upgrades
    include base::ufw
    include base::monitoring
    include ssh
    include users

    if lookup('letsencrypt') {
        include letsencrypt
    }

    if lookup('arcanist') {
        include base::arcanist
    }

    if !lookup('mailserver') {
        include base::mail
    }

    file { '/usr/local/bin/gen_fingerprints':
        ensure => present,
        source => 'puppet:///modules/base/environment/gen_fingerprints',
        mode   => '0555',
    }
    
    class { 'apt::backports':
        include => {
            'deb' => true,
            'src' => true,
        },
    }

    class { 'apt::security': }

    # Create a user to allow executing renewing ssl script between servers
    users::user { 'nagiosre':
        ensure      => present,
        uid         => 3001,
        ssh_keys    => [
            'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP1H12zO+spUhU08d/8A4zcpCpoXa2vPgAIVEJ/Fzly1 nagiosre@miraheze'
        ],
    }

    # Global vim defaults
    file { '/etc/vim/vimrc.local':
        owner  => 'root',
        group  => 'root',
        mode   => '0444',
        source => 'puppet:///modules/base/environment/vimrc.local',
    }
}
