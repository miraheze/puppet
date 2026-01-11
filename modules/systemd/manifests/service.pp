# @summary Manages a systemd-based unit as a puppet service, properly handling:
# - the unit file
# - the puppet service definition and state
# @param unit_type The unit type we are defining as a service
# @param content The content of the file.
# @param ensure The usual meta-parameter, defaults to present.
# @param restart Whether to handle restarting the service when the file changes.
# @param override If the are creating an override to system-provided units or not.
# @param override_filename When creating an override, filename to use instead of
#                          the one forged by systemd::unit.
# @param monitoring_enabled Periodically check the last execution of the unit and
#                           alarm if it ended up in a failed state.
# @param monitoring_docs_url URL of the docs for this alert.
# @param monitoring_critical If monitoring alert should be critical.
# @param service_params Additional service parameters we want to specify
#
define systemd::service (
    String $content,
    VMlib::Ensure              $ensure              = present,
    Systemd::Unit::Type        $unit_type           = 'service',
    Boolean                    $restart             = false,
    Boolean                    $override            = false,
    Optional[String[1]]        $override_filename   = undef,
    Boolean                    $monitoring_enabled  = false,
    Optional[Stdlib::HTTPSUrl] $monitoring_docs_url = undef,
    Boolean                    $monitoring_critical = false,
    Hash                       $service_params      = {},
) {
    if $unit_type == 'service' {
        $label = $title
        $provider = undef
    } else {
        # Use a fully specified label for the unit.
        $label = "${title}.${unit_type}"
        # Force the provider of the service to be systemd if the unit type is
        # not service.
        $provider = 'systemd'
    }

    $enable = $ensure ? {
        present => true,
        default   => false,
    }

    $base_params = {
        ensure   => stdlib::ensure($ensure, 'service'),
        enable   => $enable,
        provider => $provider,
    }
    $params = $base_params + $service_params
    ensure_resource('service', $label, $params)

    systemd::unit { $label:
        ensure            => $ensure,
        content           => $content,
        override          => $override,
        override_filename => $override_filename,
        restart           => $restart,
    }

    if $monitoring_enabled {
        systemd::monitor { $title:
            ensure   => $ensure,
            docs     => $monitoring_docs_url,
            critical => $monitoring_critical,
        }
    }
}
