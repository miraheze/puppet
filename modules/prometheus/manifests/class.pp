define prometheus::class (
    String $dest,
    String $module,
    Integer $port,
) {
    $servers = query_nodes("Class[${module}]")

    file { $dest:
        ensure => present,
        mode   => '0444',
        content => template('prometheus/nodes.erb')
    }
}
