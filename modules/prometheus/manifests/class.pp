define prometheus::class (
    String $dest,
    String $module,
    Integer $port,
) {
    $pdb_query = @("PQL")
        nodes[certname] {
            (resources {type = "Class" and title = "${module}"} or
            resources {type = "Define" and title = "${module}"})
            order by certname
        }
    | PQL
    $servers = puppetdb_query($pdb_query).map |$x| { $x['certname'] }
        .flatten()
        .unique()
        .sort()

    file { $dest:
        ensure  => present,
        mode    => '0444',
        content => template('prometheus/nodes.erb')
    }
}
