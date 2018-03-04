# proxy to an exported nagios_service definition
# Used as a workaround of https://tickets.puppetlabs.com/browse/PUP-6698
define monitoring::exported_nagios_service (
    $ensure,
    $host_name,
    $service_description,
    $check_command,
    $max_check_attempts,
    $check_interval,
    $retry_interval,
    $notification_interval,
    $notification_period,
    $notification_options,
    $contact_groups,
    $event_handler,
) {
    @@nagios_service { $title:
        ensure                 => $ensure,
        host_name              => $host_name,
        service_description    => $service_description,
        check_command          => $check_command,
        max_check_attempts     => $max_check_attempts,
        check_interval         => $check_interval,
        retry_interval         => $retry_interval,
        check_period           => '24x7',
        notification_interval  => 0,
        notification_period    => '24x7',
        notification_options   => 'w,u,c,r',
        contact_groups         => $contact_groups,
        passive_checks_enabled => 1,
        active_checks_enabled  => 1,
        is_volatile            => 0,
        check_freshness        => 0,
        event_handler          => $event_handler,
        target                 => '/etc/icinga/config/puppet_services.cfg',
        mode                   => '0444',
        use                    => 'generic-service',
    }
}
