# class base::puppet
class base::puppet {

    $puppetmaster_hostname = hiera('puppetmaster_hostname', 'puppet1.miraheze.org')
    $puppetmaster_version = hiera('puppetmaster_version', 4)

    if $puppetmaster_version == 6 {
        apt::source { 'puppetlabs':
            location => 'http://apt.puppetlabs.com',
            repos    => 'puppet6',
            key      => {
                'id'     => '6F6B15509CF8E59E6E469F327F438280EF8D349F',
                'server' => 'pgp.mit.edu',
            },
        }

        package { 'puppet-agent':
            ensure  => present,
            require => Apt::Source['puppetlabs'],
        }

        # facter needs this for proper "virtual"/"is_virtual" resolution
        require_package('virt-what')

        file { '/usr/bin/puppet':
            ensure  => 'link',
            target  => '/opt/puppetlabs/bin/puppet',
            require => Package['puppet-agent'],
        }

        file { '/var/log/puppet':
            ensure => directory,
            owner  => 'puppet',
            group  => 'puppet',
            mode   => '0750',
        }

        cron { 'puppet-agent':
            command => '/usr/bin/puppet agent -tv >> /var/log/puppet/puppet.log',
            user    => 'root',
            hour    => '*',
            minute  => '*/10',
        }

        logrotate::conf { 'puppet':
            ensure => present,
            source => 'puppet:///modules/base/puppet/puppetlabs.puppet.logrotate.conf',
        }

        if !hiera('puppetmaster') {
            file { '/etc/puppetlabs/puppet/puppet.conf':
                ensure  => present,
                content => template("base/puppet/puppet_${puppetmaster_version}.conf.erb"),
                mode    => '0444',
                require => Package['puppet-agent'],
            }
        }
    } else {
        # deprecated
        require_package('puppet', 'facter')

        # facter needs this for proper "virtual"/"is_virtual" resolution
        require_package('virt-what')

        file { '/var/log/puppet':
            ensure => directory,
            owner  => 'puppet',
            group  => 'puppet',
            mode   => '0750',
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

        if !hiera('puppetmaster') {
            file { '/etc/puppet/puppet.conf':
                ensure => present,
                content => template("base/puppet/puppet_${puppetmaster_version}.conf.erb"),
                mode   => '0444',
            }
        }
    }

    service { 'puppet':
        ensure => stopped,
    }
}
