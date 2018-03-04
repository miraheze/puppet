# proxy to an exported nagios_host definition
# Used as a workaround of https://tickets.puppetlabs.com/browse/PUP-6698
define icinga::exported_nagios_host (
    $ensure,
    $host_name,
    $address,
    $contact_groups,
) {
    @@nagios_host { $title:
        ensure                => $ensure,
        use                   => 'generic-host',
        host_name             => $host_name,
        address               => $address,
        contact_groups        => $contact_groups,
        target                => '/etc/icinga/config/puppet_hosts.cfg',

    }
}
