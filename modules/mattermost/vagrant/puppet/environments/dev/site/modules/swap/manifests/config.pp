class swap::config {
  exec { 'Create swap file':
    command => '/bin/dd if=/dev/zero of=/swap bs=1024 count=2097152',
    creates => '/swap',
  }
  -> exec { '/sbin/mkswap /swap':
    unless => "/usr/bin/file /swap | grep -q 'swap file'",
  }
  -> file { '/swap':
    owner => 'root',
    mode  => '0600',
  }
  -> exec { '/sbin/swapon /swap':
    unless => '/sbin/swapon -s | grep -q -w /swap',
  }
  -> mount { '/swap':
    atboot => true,
    fstype => 'swap',
    device => 'swap',
  }
  -> augeas { 'Set swappiness':
    changes => 'set /files/etc/sysctl.conf/vm.swappiness 0',
  }
  -> exec { '/sbin/sysctl -e -p':
    refreshonly => true,
  }
}
