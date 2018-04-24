define icinga2::custom::services (
    $check_command,
    $host           = $::hostname,
    $retries        = 3,
    $ensure         = present,
    $check_interval = 2,
    $retry_interval = 1,
    $event_command  = undef,
    $vars           = undef,
) {
    icinga2::object::service { $title:
        ensure                 => $ensure,
        import                 => ['generic-service'],
        host_name              => $host,
        check_command          => $check_command,
        max_check_attempts     => $retries,
        check_interval         => $check_interval,
        retry_interval         => $retry_interval,
        check_period           => '24x7',
        enable_passive_checks  => true,
        enable_active_checks   => true,
        volatile               => false,
        event_command          => $event_command,
        target                 => '/etc/icinga/config/puppet_services.cfg',
        vars                   => $vars,
    }
}
