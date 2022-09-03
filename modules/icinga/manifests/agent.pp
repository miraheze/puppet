# @summary
#   Setup a Icinga agent.
#
# @param [Stdlib::Host] ca_server
#   The CA to send the certificate request to.
#
# @param [String] parent_zone
#   Name of the parent Icinga zone.
#
# @param [Hash[String, Hash]] parent_endpoints
#   Configures these endpoints of the parent zone.
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
# @param [String] zone
#   Set a dedicated zone name.
#
# @param [Boolean] run_web
#   Prepare to run Icinga Web 2 on the same machine. Manage a group `icingaweb2`
#   and add the Icinga user to this group.
#
class icinga::agent(
  Stdlib::Host                    $ca_server,
  Hash[String, Hash]              $parent_endpoints,
  String                          $parent_zone   = 'main',
  Array[String]                   $global_zones  = [],
  Enum['file', 'syslog']          $logging_type  = 'file',
  Optional[Icinga::LogLevel]      $logging_level = undef,
  String                          $zone          = 'NodeName',
  Boolean                         $run_web       = false,
) {

  class { '::icinga':
    ca              => false,
    ssh_private_key => undef,
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

  ::icinga2::object::zone { $global_zones:
    global => true,
  }

}
