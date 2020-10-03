#

class  { 'syslog_ng':
  config_file                 => '/tmp/syslog-ng.conf',
  manage_package              => false,
  syntax_check_before_reloads => false,
  user                        => 'fwernli',
  group                       => 'fwernli',
  manage_init_defaults        => false,
}

syslog_ng::config { 'block foo':
  content => "block destination coloss(server())
      {network('`server`' transport(udp) port(514) flags(syslog-protocol))};"
}

$_coloss_analyzers = ['a','b','c']
$_coloss_analyzer_destinations = $_coloss_analyzers.map |$host| {{'coloss' => "server(${host})"}}
puts($_coloss_analyzer_destinations)
::syslog_ng::log { 'd_check_elasticsearch_roundtrip':
  params => flatten(
    [
      {'source'      => 's_check_elasticsearch_roundtrip'},
      {'rewrite'     => 'r_sdata_smurf'},
      {'rewrite'     => 'r_sdata_facter'},
      {'destination' => $_coloss_analyzer_destinations},
      #{'destination' => [{'coloss' => 'server(cc1)' }, {'coloss' => 'server(cc1)' }]},
    ]
  ),
}
