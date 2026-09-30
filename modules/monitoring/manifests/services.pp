define monitoring::services (
    $check_command,
    $host           = $facts['networking']['hostname'],
    $retries        = 3,
    $ensure         = present,
    $check_interval = '2m',
    $retry_interval = '1m',
    $event_command  = undef,
    $docs           = undef,
    $critical       = false,
    $vars = undef,
    Optional[Monitoring::PhorgeTask] $phorge_task     = undef,
    Array[Monitoring::PhorgeProject] $phorge_projects = [],
) {
    if $phorge_task == undef and !$phorge_projects.empty {
        fail("monitoring::services[${title}] sets phorge_projects without phorge_task")
    }

    $base_vars = $vars ? {
        undef   => {},
        default => $vars,
    }

    $service_vars = $phorge_task ? {
        undef   => $vars,
        default => $base_vars + {
            'phorge_task'     => $phorge_task,
            'phorge_projects' => $phorge_projects,
        },
    }

    @@icinga2::object::service { "${facts['networking']['hostname']} ${title}":
        ensure                => $ensure,
        import                => ['generic-service'],
        host_name             => $host,
        display_name          => $title,
        check_command         => $check_command,
        max_check_attempts    => $retries,
        check_interval        => $check_interval,
        retry_interval        => $retry_interval,
        check_period          => '24x7',
        enable_passive_checks => true,
        enable_active_checks  => true,
        volatile              => false,
        event_command         => $event_command,
        notes_url             => $docs,
        target                => '/etc/icinga2/conf.d/puppet_services.conf',
        vars                  => $service_vars,
    }
}
