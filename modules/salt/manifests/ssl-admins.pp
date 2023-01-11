class ssl_admins::puppetns {

  file { '/usr/bin/puppet agent -tv':
    ensure  => 'file',
    owner   => 'root',
    group   => 'ssl-admins',
    mode    => '0440',
    content => "puppet agent -t",
  }

  salt_cmd { 'run_puppet':
    command  => '/usr/bin/puppet agent -tv',
    user     => 'root',
    group    => 'ssl-admins',
    require  => File['/usr/bin/puppet agent -tv'],
  }

}
