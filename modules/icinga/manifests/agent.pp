# @summary
#   Setup an Icinga agent.
#
# @param ca_server
#   The CA to send the certificate request to.
#
# @param parent_zone
#   Name of the parent Icinga zone.
#
# @param parent_endpoints
#   Configures these endpoints of the parent zone.
#
# @param global_zones
#   List of global zones to configure.
#
# @param logging_type
#   Switch the log target. On Windows `syslog` is ignored, `eventlog` on all other platforms.
#
# @param logging_level
#   Set the log level.
#
# @param zone
#   Set a dedicated zone name.
#
# @param run_web
#   Prepare to run Icinga Web 2 on the same machine. Manage a group `icingaweb2`
#   and add the Icinga user to this group.
#
class icinga::agent (
  Stdlib::Host                       $ca_server,
  Hash[String[1], Hash]              $parent_endpoints,
  Icinga::LogLevel                   $logging_level,
  Enum['file', 'syslog', 'eventlog'] $logging_type,
  String[1]                          $parent_zone   = 'main',
  Array[String[1]]                   $global_zones  = [],
  String[1]                          $zone          = 'NodeName',
  Boolean                            $run_web       = false,
) {
  class { 'icinga':
    ca              => false,
    ca_server       => $ca_server,
    this_zone       => $zone,
    zones           => {
      'ZoneName'   => { 'endpoints' => { 'NodeName' => {} }, 'parent' => $parent_zone, },
      $parent_zone => { 'endpoints' => $parent_endpoints, },
    },
    logging_type    => $logging_type,
    logging_level   => $logging_level,
    prepare_web     => $run_web,
  }

  icinga2::object::zone { $global_zones:
    global => true,
    order  => 'zz',
  }
}
