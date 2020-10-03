class  { 'syslog_ng':
  config_file                 => '/tmp/syslog-ng.conf',
  manage_package              => false,
  syntax_check_before_reloads => false,
  user                        => 'fwernli',
  group                       => 'fwernli',
  manage_init_defaults        => false,
}

syslog_ng::config {'version':
    content => '@version: 3.6',
    order   => '02'
}

$long_comment = '# Comment,
# wich spawns over multiple lines
# '

syslog_ng::config {'long_comment':
    content => $long_comment
}
