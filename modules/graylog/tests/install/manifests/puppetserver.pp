package { 'puppetserver':
  ensure => installed,
}

file { 'sysconfig-puppetserver':
  ensure  => file,
  path    => '/etc/sysconfig/puppetserver',
  source  => '/vagrant/tests/install/files/sysconfig-puppetserver',
  require => Package['puppetserver'],
}

service { 'puppetserver':
  ensure  => true,
  enable  => true,
  require => [Package['puppetserver'],File['sysconfig-puppetserver']],
}
