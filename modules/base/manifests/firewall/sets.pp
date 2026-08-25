class base::firewall::sets {
    include network::constants

    $network::constants::host_groups.each |$name, $ips| {
        firewall::set { "${name.upcase()}_HOSTS":
            ips => $ips,
        }
    }
}
