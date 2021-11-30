# Class used to add support for various php versions
class php::apt (
  Enum['7.0', '7.1', '7.2', '7.3', '7.4'] $php_version = '7.3'
) {
    # Only need this for buster and if php version selected in 7.4
    if $php_version === '7.4' and os_version('debian buster') {
        include ::apt

        file { '/etc/apt/trusted.gpg.d/php.gpg':
            ensure => present,
            source => 'puppet:///modules/php/key/php.gpg',
        }

        # We use wikimedias php 7.4 repo to get the 7.4 packages.
        apt::source { 'wikimedia-php74':
            location => 'http://apt.wikimedia.org/wikimedia',
            release  => "${::lsbdistcodename}-wikimedia",
            repos    => 'component/php74',
            notify   => Exec['apt_update_php'],
            require  => File['/etc/apt/trusted.gpg.d/php.gpg'],
            before   => Package['php7.4-common', 'php7.4-opcache'] # To prevent installing problems
        }

         apt::pin { 'php_pin':
            priority        => 600,
            origin          => 'apt.wikimedia.org'
        }

        # First installs can trip without this
        exec {'apt_update_php':
            command     => '/usr/bin/apt-get update',
            refreshonly => true,
            require     => Apt::Pin['php_pin'],
        }
    }
}
