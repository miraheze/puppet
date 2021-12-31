class role::bastion {
    $firewall_rules_str = join(
        query_facts("domain='$domain'", ['ipaddress', 'ipaddress6'])
        .map |$key, $value| {
            "${value['ipaddress']} ${value['ipaddress6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'bastion':
        proto   => 'tcp',
        port    => '8080',
        srange  => "(${firewall_rules_str})",
    }
}
