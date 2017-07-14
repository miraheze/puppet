# class base::puppet
class base::puppet {
    cron { 'puppet-run-no-force':
        ensure  => absent,
        command => '/root/puppet-run &> /var/log/puppet-run.log',
        user    => 'root',
        minute  => [ 10, 20, 30, 40, 50 ],
    }

    cron { 'puppet-run-force':
        ensure  => absent,
        command => '/root/puppet-run -f &> /var/log/puppet-run.log',
        user    => 'root',
        hour    => '*',
        minute  => '0',
    }

    cron { 'puppet-agent':
        command => '/usr/bin/puppet agent -t',
        user    => 'root',
        hour    => '*',
        minute  => '*/10',
    }

    file { '/root/puppet-run':
        ensure => absent,
        source => 'puppet:///modules/base/puppet/puppet-run',
        mode   => '0775',
    }

    if !hiera('puppetmaster') {
        file { '/etc/puppet/puppet.conf':
            ensure => present,
            source => 'puppet:///modules/base/puppet/puppet.conf',
            mode   => '0444',
        }
    }

    service { 'puppet':
        ensure => stopped,
    }
}
