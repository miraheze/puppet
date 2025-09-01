# class: base
class base (
    String $bots_hostname = lookup('base::bots_hostname'),
    Optional[String] $http_proxy = lookup('http_proxy', {'default_value' => undef}),
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
    include base::mail
    include base::monitoring
    include ssh
    include users

    if lookup('dns') {
        package { 'pdns-recursor':
            ensure => absent,
        }
    } else {
        include base::dns
    }

    file { '/usr/local/bin/gen_fingerprints':
        ensure => present,
        source => 'puppet:///modules/base/environment/gen_fingerprints',
        mode   => '0555',
    }

    file { '/usr/local/bin/logsalmsg':
        ensure  => present,
        content => template('base/logsalmsg.erb'),
        mode    => '0555',
    }

    file { '/usr/local/bin/secupgrade.sh':
        ensure => present,
        source => 'puppet:///modules/base/secupgrade.sh',
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

    class { 'ntp':
        servers   => [ 'time.cloudflare.com' ],
        config    => '/etc/ntpsec/ntp.conf',
        driftfile => '/var/lib/ntpsec/ntp.drift',
        restrict  => [
            'default kod limited nomodify noquery',
            '-6 default kod limited nomodify noquery',
            '127.0.0.1',
            '-6 ::1',
            '10.0.0.0 mask 255.0.0.0 nomodify notrap',
        ],
    }

    # Used by salt-user
    users::user { 'salt-user':
        ensure     => present,
        uid        => 3100,
        ssh_keys   => [
            'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHTYeA06i16YF6VeCO0ctaCaSgK/8rNQ32aJqx9eNXmJ salt-user@puppet181'
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

    # Global bash defaults
    file { '/etc/bash.bashrc':
        owner  => 'root',
        group  => 'root',
        mode   => '0444',
        source => 'puppet:///modules/base/environment/bash.bashrc',
    }

    # Global bash defaults
    file { '/etc/skel/.bashrc':
        owner  => 'root',
        group  => 'root',
        mode   => '0444',
        source => 'puppet:///modules/base/environment/.bashrc',
    }
}
