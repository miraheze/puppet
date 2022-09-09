# @summary
#   Setup a Icinga worker (aka satellite).
#
# @param [Stdlib::Host] ca_server
#   The CA to send the certificate request to.
#
# @param [String] zone
#   Name of the Icinga zone.
#
# @param [String] parent_zone
#   Name of the parent Icinga zone.
#
# @param [Hash[String, Hash]] parent_endpoints
#   Configures these endpoints of the parent zone.
#
# @param [Hash[String, Hash]] colocation_endpoints
#   When the zone includes more than one endpoint, set here the additional endpoint(s).
#   Icinga supports two endpoints per zone only.
#
# @param [Array[String]] global_zones
#   List of global zones to configure.
#
# @param [Enum['file', 'syslog']] logging_type
#   Switch the log target. Only `file` is supported on Windows.
#
# @param [Optional[Icinga::LogLevel]] logging_level
#   Set the log level.
#
# @param [Boolean] run_web
#   Prepare to run Icinga Web 2 on the same machine. Manage a group `icingaweb2`
#   and add the Icinga user to this group.
#
class icinga::worker(
  Stdlib::Host                    $ca_server,
  String                          $zone,
  Hash[String, Hash]              $parent_endpoints,
  String                          $parent_zone          = 'main',
  Hash[String, Hash]              $colocation_endpoints = {},
  Array[String]                   $global_zones         = [],
  Enum['file', 'syslog']          $logging_type         = 'file',
  Optional[Icinga::LogLevel]      $logging_level        = undef,
  Boolean                         $run_web              = false,
) {

  class { '::icinga':
    ca              => false,
    ssh_private_key => undef,
    ca_server       => $ca_server,
    this_zone       => $zone,
    zones           => {
      'ZoneName'   => { 'endpoints' => { 'NodeName' => {} } + $colocation_endpoints, 'parent' => $parent_zone, },
      $parent_zone => { 'endpoints' => $parent_endpoints, },
    },
    logging_type    => $logging_type,
    logging_level   => $logging_level,
    prepare_web     => $run_web,
  }

  include ::icinga2::feature::checker

  ::icinga2::object::zone { $global_zones:
    global => true,
  }
}
