# Fail2ban setup
class fail2ban {
  stdlib::ensure_packages(['fail2ban']);

  file { '/etc/fail2ban/filter.d/miraheze-custom-01.conf':
    ensure  => 'file',
    source  => 'puppet:///private/fail2ban/miraheze-custom-01.conf',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => Package['fail2ban'],
    notify  => Service['fail2ban'],
  }

  # Disable default jail config
  file { '/etc/fail2ban/jail.d':
    ensure  => 'directory',
    recurse => true,
    purge   => true,
    require => Package['fail2ban'],
  }

  file { '/etc/fail2ban/jail.local':
    ensure  => 'file',
    source  => 'puppet:///private/fail2ban/jail.local',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => File['/etc/fail2ban/filter.d/miraheze-custom-01.conf'],
    notify  => Service['fail2ban'],
  }

  service { 'fail2ban':
    ensure  => 'running',
    enable  => true,
    require => Package['fail2ban'],
  }
}
