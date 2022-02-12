define prometheus::class (
    String $dest,
    String $class,
    Integer $port,
) {
    $servers = query_nodes("Class[${class}]")

    file { $dest,
        ensure => present,
        mode   => '0444',
        content => template('prometheus/nodes.erb')
    }
}
