class  { 'syslog_ng':
  config_file                 => '/tmp/syslog-ng.conf',
  manage_package              => false,
  syntax_check_before_reloads => false,
  user                        => 'fwernli',
  group                       => 'fwernli',
  manage_init_defaults        => false,
}

$coloss_analyzer = 'coloss-analyzer.in2p3.fr'
$coloss_analyzers = ['coloss-analyzer-failover.in2p3.fr', 'coloss-analyzer.in2p3.fr']
::syslog_ng::destination { 'd_coloss':
  params => [
    { 'syslog-ng' => flatten([
        { 'server'     => "'${coloss_analyzer}'" },
        { 'failover'   => [
          { 'servers'  => $coloss_analyzers.map |$server| {"\"${server}\""} },
          { 'failback' => [ 'successful-probes-required(3)', 'tcp-probe-interval(5)' ] },
        ],
        },
        { 'port'       => 514 },
        $options])
    }
  ]
}

