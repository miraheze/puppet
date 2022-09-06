class  { 'syslog_ng':
  config_file                 => '/tmp/syslog-ng.conf',
  manage_package              => false,
  syntax_check_before_reloads => false,
  user                        => 'fwernli',
  group                       => 'fwernli',
  manage_init_defaults        => false,
}

syslog_ng::rewrite { 'r_truncate':
  params => [
    # lint:ignore:single_quote_string_with_variables
    { 'set' => ['"$(substr ${MSG} 0 14400))"'] }
    # lint:endignore
  ]
}
