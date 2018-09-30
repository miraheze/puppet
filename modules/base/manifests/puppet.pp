# class base::puppet
class base::puppet {
    
    require_package('puppet', 'facter')

    # facter needs this for proper "virtual"/"is_virtual" resolution
    require_package('virt-what')

    $puppetmaster_hostname = hiera('puppetmaster_hostname', 'puppet1.miraheze.org')
    $puppetmaster_version = hiera('puppetmaster_version', 4)

    file { '/var/log/puppet':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    cron { 'puppet-agent':
        command => '/usr/bin/puppet agent -tv >> /var/log/puppet/puppet.log',
        user    => 'root',
        hour    => '*',
        minute  => '*/10',
    }

    logrotate::conf { 'puppet':
        ensure => present,
        source => 'puppet:///modules/base/puppet/puppet.logrotate.conf',
    }

    file { '/root/puppet-run':
        ensure => absent,
        source => 'puppet:///modules/base/puppet/puppet-run',
        mode   => '0775',
    }

    if !hiera('puppetmaster') {
        file { '/etc/puppet/puppet.conf':
            ensure => present,
            content => template("base/puppet/puppet_${puppetmaster_version}.conf.erb"),
            mode   => '0444',
        }
    }

    service { 'puppet':
        ensure => stopped,
    }
}
