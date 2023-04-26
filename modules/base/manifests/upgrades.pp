# class base::upgrades
class base::upgrades {
    package { 'unattended-upgrades':
        ensure => present,
    }

    file { '/etc/apt/apt.conf.d/50unattended-upgrades':
        ensure  => present,
        source  => 'puppet:///modules/base/apt/50unattended-upgrades',
        require => Package['unattended-upgrades'],
    }

    file { '/etc/apt/apt.conf.d/20auto-upgrades':
        ensure  => present,
        source  => 'puppet:///modules/base/apt/20auto-upgrades',
        require => Package['unattended-upgrades'],
    }
}
