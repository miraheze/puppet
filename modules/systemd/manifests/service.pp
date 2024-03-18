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
# @param team The team which owns this service
# @param service_params Additional service parameters we want to specify
#
define systemd::service (
    String $content,
    VMlib::Ensure       $ensure            = 'present',
    Systemd::Unit::Type $unit_type         = 'service',
    Boolean             $restart           = false,
    Boolean             $override          = false,
    Optional[String[1]] $override_filename = undef,
    Hash                $service_params    = {},
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
        'present' => true,
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
}
