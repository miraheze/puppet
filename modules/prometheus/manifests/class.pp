define prometheus::class (
    String $dest,
    String $module,
    Integer $port,
    Boolean $public = false,
    String $public_dest = regsubst($dest, '^(.*)/([^/]+)$', '\\1/public/\\2'),
) {
    $pdb_query = @("PQL")
        nodes[certname] {
            (resources {type = "Class" and title = "${module}"} or
            resources {type = "${module}"})
            order by certname
        }
    | PQL
    $servers = puppetdb_query($pdb_query).map |$x| { $x['certname'] }
        .flatten()
        .unique()
        .sort()

    $groups = vmlib::scrape_groups($servers, $port)

    file { $dest:
        ensure  => present,
        mode    => '0444',
        content => epp('prometheus/nodes.epp', { 'groups' => $groups['internal'] }),
    }

    if $public {
        file { $public_dest:
            ensure  => present,
            mode    => '0444',
            content => epp('prometheus/nodes.epp', { 'groups' => $groups['public'] }),
        }
    }
}
