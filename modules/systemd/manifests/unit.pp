# @summary This define creates a file on the filesystem at $path,
#   schedules a daemon-reload of systemd and, if requested,
#   schedules a subsequent refresh of the service.
# @param title The resource title is assumed to be the corresponding full unit
#   name. If no valid unit suffix is present, 'service' will be assumed.
# @param content The content of the file. Required.
# @param ensure The usual meta-parameter, defaults to present.
# @param unit The name of the unit by default use the title
# @param restart Whether to handle restarting the service when the file changes.
# @param override If the are creating an override to system-provided units or not.
# @param override_filename When creating an override, filename to use for the override. The given
#   filename would have the `.conf` extension added if missing.
#   Defaults to undef (use `puppet-override.conf`)
# @param team The team which owns this service
#
# @example A systemd override for the hhvm.service unit
#
# systemd::unit { 'hhvm':
#     ensure   => present,
#     content  => template('hhvm/initscripts/hhvm.systemd.erb'),
#     restart  => false,
#     override => true,
# }
#
# # A socket for nginx
# systemd::unit { 'nginx.socket':
#     ensure   => present,
#     content  => template('nginx/nginx.socket.erb'),
#     restart  => true, # This will work only if you have service{ `nginx.socket`: }
# }
#
define systemd::unit (
    Optional[String]             $content           = undef,
    Optional[Stdlib::Filesource] $source            = undef,
    VMlib::Ensure                $ensure            = present,
    String                       $unit              = $title,
    Boolean                      $restart           = false,
    Boolean                      $override          = false,
    String[1]                    $override_filename = 'puppet-override.conf',
) {
    require systemd

    if ($source == undef) == ($content == undef) {
        fail("systemd::unit: ${title}: either source or content must be provided, but not both")
    }

    if ($unit =~ /^(.+)\.(\w+)$/ and $2 =~ Systemd::Unit::Type) {
        $unit_name = $unit
    } else {
        $unit_name = "${unit}.service"
    }

    if ($override) {
        # Define the override dir if not defined.
        $override_dir = "${systemd::override_dir}/${unit_name}.d"
        if $ensure == 'present' {
            # Only manage this directory on creation.  This means that we
            # may end up with some empty directories but that shuoldn't mater
            # TODO: Add recurs/purge => true
            ensure_resource('file', $override_dir, {
                ensure => directory,
                owner  => 'root',
                group  => 'root',
                mode   => '0555',
            })
        }

        $path = $override_filename ? {
            /\.conf$/ => "${override_dir}/${override_filename}",
            default   => "${override_dir}/${override_filename}.conf",
        }
    } else {
        $path = "${systemd::base_dir}/${unit_name}"
    }

    $exec_label = "systemd daemon-reload for ${unit_name} (${title})"
    file { $path:
        ensure  => $ensure,
        source  => $source,
        content => $content,
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        notify  => Exec[$exec_label],
    }

    exec { $exec_label:
        refreshonly => true,
        command     => '/bin/systemctl daemon-reload',
    }

    # If the unit  is defined as a service, add a dependency.

    if defined(Service[$unit]) {
        if $ensure == 'present' {
            # systemd must reload units before the service is managed
            if $restart {
                # Refresh the service if restarts are required
                Exec[$exec_label] ~> Service[$unit]
            } else {
                Exec[$exec_label] -> Service[$unit]
            }
        } else {
            # the service should be managed before the daemon-reload
            Service[$unit] -> Exec[$exec_label]
        }
    }
}