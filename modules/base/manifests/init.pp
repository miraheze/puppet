# class: base
class base (
    Optional[String] $http_proxy = lookup('http_proxy', {'default_value' => undef})
) {
    include apt
    include base::packages
    include base::puppet
    include base::syslog
    include base::ssl
    include base::sysctl
    include base::timezone
    include base::upgrades
    include base::firewall
    include base::monitoring
    include ssh
    include users

    if !lookup('mailserver') {
        include base::mail
    }

    if !lookup('dns') {
        include base::dns
    }

    file { '/usr/local/bin/gen_fingerprints':
        ensure => present,
        source => 'puppet:///modules/base/environment/gen_fingerprints',
        mode   => '0555',
    }

    file { '/usr/local/bin/logsalmsg':
        ensure => present,
        source => 'puppet:///modules/base/logsalmsg',
        mode   => '0555',
    }

    if $http_proxy {
        file { '/etc/gitconfig':
            ensure  => present,
            content => template('base/git/gitconfig.erb'),
        }
    }

    class { 'apt::backports':
        include => {
            'deb' => true,
            'src' => true,
        },
    }

    class { 'apt::security': }

    # Used by salt-user
    users::user { 'salt-user':
        ensure     => present,
        uid        => 3100,
        ssh_keys   => [
            'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILVTOQ4vISRH4ictbbGprgCDFt7iU7hEE0HXjOOrlKvU salt-user@miraheze'
        ],
        privileges => ['ALL = (ALL) NOPASSWD: ALL'],
    }

    # Global vim defaults
    file { '/etc/vim/vimrc.local':
        owner  => 'root',
        group  => 'root',
        mode   => '0444',
        source => 'puppet:///modules/base/environment/vimrc.local',
    }
}
