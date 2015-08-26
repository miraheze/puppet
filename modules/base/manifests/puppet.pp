# class base::puppet
class base::puppet {
    cron { 'puppet-run-no-force':
        command => "/root/puppet-run &> /var/log/puppet-run.log",
        user    => 'root',
        minute  => [ 10, 20, 30, 40, 50 ],
    }

    cron { 'puppet-run-force':
        command => "/root/puppet-run -f &> /var/log/puppet-run.log",
        user    => 'root',
        hour    => '*',
        minute  => '0',
    }

    file { '/root/puppet-run':
        ensure => present,
        source => 'puppet:///modules/base/puppet/puppet-run',
        mode   => '0775',
    }

    file { '/etc/puppet/hiera.yaml':
        ensure => present,
        source => 'puppet:///modules/base/puppet/hiera.yaml',
        mode   => '0444',
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

    file { '/root/id_rsa':
        ensure => present,
        source => 'puppet:///private/ssh/id_rsa',
        mode   => '0400',
    }
}
