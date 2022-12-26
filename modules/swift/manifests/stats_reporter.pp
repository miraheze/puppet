# SPDX-License-Identifier: Apache-2.0
class swift::stats_reporter (
    VMlib::Ensure        $ensure,
    Hash[String, Hash]   $accounts,
    Hash[String, String] $credentials,
){

    class { 'swift::stats::dispersion':
        ensure        => $ensure,
        statsd_host   => 'localhost',
        statsd_port   => '9125',
    }

    class { 'swift::stats::accounts':
        ensure      => $ensure,
        accounts    => $accounts,
        credentials => $credentials,
        statsd_host => 'localhost',
        statsd_port => '9125',
    }
}
