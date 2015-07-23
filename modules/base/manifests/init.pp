# class: base
class base {
    include base::packages
    include base::monitoring
    include base::ufw
    include ssh
    include users

    file { '/root/puppet-run':
        ensure => present,
        source => 'puppet:///modules/base/puppet/puppet-run',
        mode   => '0775',
    }

    file { '/etc/puppet/puppet.conf':
        ensure => present,
        source => 'puppet:///modules/base/puppet/puppet.conf',
        mode   => '0444',
    }

    file { '/etc/puppet/fileserver.conf':
        ensure => present,
        source => 'puppet:///modules/base/puppet/fileserver.conf',
        mode   => '0444',
    }

    file { '/etc/puppet/private':
        ensure => link,
        target => '/root/private',
    }

    if $::hostname != "misc1" {
        mailalias { 'root':
            recipient => 'root@miraheze.org',
        }
    }
}
