# == Class: icinga2::repo
#
# This class manages the packages.icinga.com repository based on the operating system.
class icinga2::repo {
    include ::apt, ::apt::backports

    apt::source { 'icinga-stable-release':
        location => 'http://packages.icinga.com/debian',
        release  => "icinga-${::lsbdistcodename}",
        repos    => 'main',
        key      => {
          id     => 'F51A91A5EE001AA5D77D53C4C6E319C334410682',
          source => 'http://packages.icinga.com/icinga.key',
        },
        require  => Class['::apt::backports'],
        notify   => Exec['apt_update_icinga2'],
    }

    # First installs can trip without this
    exec {'apt_update_icinga2':
      command     => '/usr/bin/apt-get update',
      refreshonly => true,
      logoutput   => true,
    }
}
