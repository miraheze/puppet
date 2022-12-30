# SPDX-License-Identifier: Apache-2.0
class swift::stats::accounts(
    Hash[String, Hash] $accounts,
    Hash[String, String] $credentials,
    VMlib::Ensure $ensure = present,
    $statsd_host   = 'localhost',
    $statsd_port   = 9125,
    $statsd_prefix = "swift.stats",
) {
    $required_packages = [
        Package['python3-swiftclient'],
        Package['python3-statsd'],
        Package['swift'],
        ]

    file { '/usr/local/bin/swift-account-stats':
        ensure  => $ensure,
        owner   => 'root',
        group   => 'root',
        mode    => '0555',
        source  => 'puppet:///modules/swift/swift-account-stats.py',
        require => $required_packages,
    }

    file { '/usr/local/bin/swift-account-stats-timer.sh':
        ensure => $ensure,
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
        source => 'puppet:///modules/swift/swift-account-stats-timer.sh'
    }

    file { '/usr/local/bin/swift-container-stats':
        ensure  => $ensure,
        owner   => 'root',
        group   => 'root',
        mode    => '0555',
        source  => 'puppet:///modules/swift/swift-container-stats.py',
        require => $required_packages,
    }

    file { '/usr/local/bin/swift-container-stats-timer.sh':
        ensure => $ensure,
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
        source => 'puppet:///modules/swift/swift-container-stats-timer.sh'
    }

    $account_names = sort(keys($accounts))
    swift::stats::stats_account { $account_names:
        ensure        => $ensure,
        accounts      => $accounts,
        statsd_prefix => $statsd_prefix,
        statsd_host   => $statsd_host,
        statsd_port   => $statsd_port,
        credentials   => $credentials,
    }
}
