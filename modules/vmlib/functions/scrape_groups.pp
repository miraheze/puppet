function vmlib::scrape_groups (
    Array[String] $servers,
    Integer       $port,
) >> Hash {
    $servers_json = stdlib::to_json($servers)
    $facts_query = "nodes { certname in ${servers_json} }"
    $node_facts = $servers.empty ? {
        true    => {},
        default => puppetdb::query_facts(['networking'], $facts_query),
    }

    $entries = $servers.map |$certname| {
        $net = $node_facts[$certname] ? {
            Hash    => $node_facts[$certname]['networking'],
            default => {},
        }
        $ifaces = $net['interfaces'] ? {
            Hash    => $net['interfaces'],
            default => {},
        }

        if $ifaces['vmbr1'] {
            $private_ip = $ifaces['vmbr1']['ip']
        } elsif $ifaces['ens19'] {
            $private_ip = $ifaces['ens19']['ip']
        } else {
            $private_ip = undef
        }

        if $ifaces['vmbr1'] or $ifaces['ens19'] {
            if $certname =~ /\.fsslc\.wtnet$/ {
                $entry = { 'certname' => $certname, 'public' => false, 'address' => $certname, 'alias' => false }
            } elsif $private_ip =~ String {
                $entry = { 'certname' => $certname, 'public' => false, 'address' => $private_ip, 'alias' => true }
            } else {
                $entry = { 'certname' => $certname, 'public' => false, 'address' => "${net['hostname']}.fsslc.wtnet", 'alias' => true }
            }
        } elsif $ifaces.empty {
            $entry = { 'certname' => $certname, 'public' => false, 'address' => $certname, 'alias' => false }
        } else {
            $entry = { 'certname' => $certname, 'public' => true, 'address' => $certname, 'alias' => false }
        }

        $entry
    }

    $plain = $entries.filter |$e| { !$e['public'] and !$e['alias'] }.map |$e| { "${e['address']}:${port}" }
    $public = $entries.filter |$e| { $e['public'] }.map |$e| { "${e['certname']}:${port}" }

    $aliased = $entries.filter |$e| { $e['alias'] }.map |$e| {
        $group = {
            'targets' => ["${e['address']}:${port}"],
            'labels'  => { 'instance' => "${e['certname']}:${port}" },
        }
        $group
    }

    $plain_groups = $plain.empty ? {
        true    => $aliased.empty ? {
            true    => [{ 'targets' => [] }],
            default => [],
        },
        default => [{ 'targets' => $plain }],
    }
    $public_groups = [{ 'targets' => $public }]

    $result = {
        'internal' => $plain_groups + $aliased,
        'public'   => $public_groups,
    }

    $result
}
