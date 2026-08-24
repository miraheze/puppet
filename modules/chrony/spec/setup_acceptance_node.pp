if fact('os.family') == 'redhat' {
  file { '/var/run/chrony':
    ensure => directory,
  }
}
if fact('os.family') == 'Archlinux' {
  file { '/etc/sysconfig':
    ensure => directory,
  }
}
