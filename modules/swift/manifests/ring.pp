# SPDX-License-Identifier: Apache-2.0
class swift::ring {

    # lint:ignore:puppet_url_without_modules
    file { '/etc/swift/account.builder':
        ensure    => present,
        source    => 'puppet:///private/swift/account.builder',
        show_diff => false,
    }

    file { '/etc/swift/account.ring.gz':
        ensure => present,
        source => 'puppet:///private/swift/account.ring.gz',
    }

    file { '/etc/swift/container.builder':
        ensure    => present,
        source    => 'puppet:///private/swift/container.builder',
        show_diff => false,
    }

    file { '/etc/swift/container.ring.gz':
        ensure => present,
        source => 'puppet:///private/swift/container.ring.gz',
    }

    file { '/etc/swift/object.builder':
        ensure    => present,
        source    => 'puppet:///private/swift/object.builder',
        show_diff => false,
    }

    file { '/etc/swift/object.ring.gz':
        ensure => present,
        source => 'puppet:///private/swift/object.ring.gz',
    }
}
