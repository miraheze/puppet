# class base::puppet
class base::puppet (
    Integer[1,59] $interval              = lookup('base::puppet::interval', {'default_value' => 30}),
    Integer       $puppet_major_version  = lookup('puppet_major_version', {'default_value' => 8}),
    String        $puppetserver_hostname = lookup('puppetserver_hostname'),
) {
    file { '/etc/apt/trusted.gpg.d/openvox-keyring.gpg':
        ensure => present,
        source => 'puppet:///modules/base/puppet/openvox-keyring.gpg',
    }

    apt::source { 'openvox':
        location => 'https://apt.voxpupuli.org',
        repos    => "openvox${puppet_major_version}",
        release  => "debian${facts['os']['release']['major']}",
        require  => File['/etc/apt/trusted.gpg.d/openvox-keyring.gpg'],
        notify   => Exec['apt_update_openvox'],
    }

    exec {'apt_update_openvox':
        command     => '/usr/bin/apt-get update',
        refreshonly => true,
        logoutput   => true,
    }

    package { 'openvox-agent':
        ensure  => present,
        require => Apt::Source['openvox'],
    }

    # facter needs this for proper "virtual"/"is_virtual" resolution
    stdlib::ensure_packages('virt-what')

    file { '/usr/bin/facter':
        ensure  => link,
        target  => '/opt/puppetlabs/bin/facter',
        require => Package['openvox-agent'],
    }

    file { '/usr/bin/hiera':
        ensure  => link,
        target  => '/opt/puppetlabs/bin/hiera',
        require => Package['openvox-agent'],
    }

    file { '/usr/bin/puppet':
        ensure  => 'link',
        target  => '/opt/puppetlabs/bin/puppet',
        require => Package['openvox-agent'],
    }

    file { '/var/log/puppet':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0750',
    }

    file { '/usr/local/sbin/puppet-run':
        mode    => '0555',
        owner   => 'root',
        group   => 'root',
        content => template('base/puppet/puppet-run.erb'),
        require => File['/var/log/puppet'],
    }

    $minute = fqdn_rand($interval, 'puppet_agent_timer')
    $timer_interval = "*:${minute}/${interval}:00"

    systemd::timer::job { 'puppet-agent-timer':
        ensure             => present,
        description        => "Run Puppet agent every ${interval} minutes",
        user               => 'root',
        ignore_errors      => true,
        monitoring_enabled => false,
        command            => '/usr/local/sbin/puppet-run',
        interval           => [
            { 'start' => 'OnCalendar', 'interval' => $timer_interval },
            { 'start' => 'OnStartupSec', 'interval' => '1min' },
        ],
    }

    logrotate::conf { 'puppet':
        ensure => present,
        source => 'puppet:///modules/base/puppet/puppetlabs.puppet.logrotate.conf',
    }

    if !lookup('puppetserver') {
        file { '/etc/puppetlabs/puppet/puppet.conf':
            ensure  => present,
            content => template('base/puppet/puppet.conf.erb'),
            mode    => '0444',
            require => Package['openvox-agent'],
        }
    }

    service { 'puppet':
        ensure => stopped,
        enable => false,
    }

    file { '/usr/local/bin/puppet-enabled':
        mode   => '0555',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/base/puppet/puppet-enabled',
    }

    motd::script { 'last-puppet-run':
        ensure   => present,
        priority => 97,
        source   => 'puppet:///modules/base/puppet/97-last-puppet-run',
    }
}
