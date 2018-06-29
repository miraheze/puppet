# == Class: swift

class swift {

    require_package('swift')

    file { '/etc/swift/swift.conf':
        ensure  => present,
        source  => 'puppet:///modules/swift/swift.conf',
        require => Package['swift'],
    }

    file { '/var/lock/swift':
        ensure  => directory,
    }

    file { '/var/log/swift':
        ensure  => directory,
    }

    file { '/var/lib/swift':
        ensure  => directory,
    }

    git::clone { 'swift':
        ensure    => present,
        directory => '/srv/swift',
        origin    => 'https://github.com/miraheze/rings.git',
        branch    => 'master',
        owner     => 'root',
        group     => 'root',
        mode      => '0755',
        timeout   => '550',
        require   => Package['swift'],
    }

    file { '/etc/swift/account.builder':
        ensure  => 'link',
        target  => '/srv/swift/account.builder',
        require => [Package['swift'], Git::Clone['swift']],
    }

    file { '/etc/swift/account.ring.gz':
        ensure  => 'link',
        target  => '/srv/swift/account.ring.gz',
        require => [Package['swift'], Git::Clone['swift']],
    }

    file { '/etc/swift/container.builder':
        ensure  => 'link',
        target  => '/srv/swift/container.builder',
        require => [Package['swift'], Git::Clone['swift']],
    }

    file { '/etc/swift/container.ring.gz':
        ensure  => 'link',
        target  => '/srv/swift/container.ring.gz',
        require => [Package['swift'], Git::Clone['swift']],
    }

    file { '/etc/swift/object.builder':
        ensure  => 'link',
        target  => '/srv/swift/object.builder',
        require => [Package['swift'], Git::Clone['swift']],
    }

    file { '/etc/swift/object.ring.gz':
        ensure  => 'link',
        target  => '/srv/swift/object.ring.gz',
        require => [Package['swift'], Git::Clone['swift']],
    }

    if hiera('swift_proxy', false) {
        include swift::proxy
    }

    # TODO: create class
    #if hiera('swift_backend', false) {
    #    include swift::backend
    #}
}
