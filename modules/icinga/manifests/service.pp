# exports service monitoring for icinga
define icinga::service (
    $description,
    $check_command,
    $host           = $::hostname,
    $retries        = 3,
    $ensure         = present,
    $check_interval = 2,
    $retry_interval = 1,
    $contacts       = hiera('contactgroups', 'ops'),
    $event_handler  = undef,
  ) {
    $description_safe = regsubst($description, '[`~!$%^&*"|\'<>?,()=]', '-', 'G')

    $service = {
        "${::hostname} ${title}" => {
            ensure                 => $ensure,
            host_name              => $host,
            service_description    => $description_safe,
            check_command          => $check_command,
            max_check_attempts     => $retries,
            check_interval         => $check_interval,
            retry_interval         => $retry_interval,
            check_period           => '24x7',
            notification_interval  => 0,
            notification_period    => '24x7',
            notification_options   => 'w,u,c,r',
            contact_groups         => $contacts,
            passive_checks_enabled => 1,
            active_checks_enabled  => 1,
            is_volatile            => 0,
            check_freshness        => 0,
            event_handler          => $event_handler,
            target                 => '/etc/icinga/config/puppet_services.cfg',
            mode                   => '0444',
            use                    => 'generic-service',
        },
    }

    if defined(Class['icinga']) {
        create_resources(nagios_service, $service)
    } else {
        create_resources('@@nagios_service', $service)
    }
}
