# @summary
#   Setup a Icinga server.
#
# @param [Boolean] ca
#   Enables a CA on this node.
#
# @param [Boolean] config_server
#   Enables that this node is the central configuration server.
#
# @param [String] zone
#   Name of the Icinga zone.
#
# @param [Hash[String,Hash]] colocation_endpoints
#   When the zone includes more than one endpoint, set here the additional endpoint(s).
#   Icinga supports two endpoints per zone only.
#
# @param [Hash[String,Hash]] workers
#   All worker zones with key 'endpoints' for 
#   endpoint objects.
#
# @param [Array[String]] global_zones
#   List of global zones to configure.
#
# @param [Optional[Stdlib::Host]] ca_server
#   The CA to send the certificate request to.
#
# @param [Optional[String]] ticket_salt
#   Set an alternate ticket salt to icinga::ticket_salt from Hiera.
#
# @param [String] web_api_user
#   Icinga API user to connect Icinga 2. Notice: user is only created if a password is set.
#
# @param [Optional[String]] web_api_pass
#   Icinga API user password.
#
# @param [String] director_api_user
#   Icinga API director user to connect Icinga 2. Notice: user is only created if a password is set.
#
# @param [Optional[String]] director_api_pass
#   Icinga API director user password.
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
class icinga::server(
  Boolean                         $ca                   = false,
  Boolean                         $config_server        = false,
  String                          $zone                 = 'main',
  Hash[String,Hash]               $colocation_endpoints = {},
  Hash[String,Hash]               $workers              = {},
  Array[String]                   $global_zones         = [],
  Optional[Stdlib::Host]          $ca_server            = undef,
  Optional[String]                $ticket_salt          = undef,
  String                          $web_api_user         = 'icingaweb2',
  Optional[String]                $web_api_pass         = undef,
  String                          $director_api_user    = 'director',
  Optional[String]                $director_api_pass    = undef,
  Enum['file', 'syslog']          $logging_type         = 'file',
  Optional[Icinga::LogLevel]      $logging_level        = undef,
  Boolean                         $run_web              = false,
) {

  if empty($colocation_endpoints) {
    $_ca            = true
    $_config_server = true
  } else {
    if !$ca and !$ca_server {
      fail('Class[Icinga::Server]: expects a value for parameter \'ca_server\'')
    }
    $_ca            = $ca
    $_config_server = $config_server
  }

  # inject parent zone
  $_workers = parseyaml(inline_template(
    '<%= @workers.inject({}) {|h, (x,y)| h[x] = y.merge({"parent" => @zone}); h}.to_yaml %>'
  ))

  class { '::icinga':
    ca            => $_ca,
    ca_server     => $ca_server,
    this_zone     => $zone,
    zones         => merge({
      'ZoneName' => { 'endpoints' => { 'NodeName' => {}} + $colocation_endpoints },
    }, $_workers),
    logging_type  => $logging_type,
    logging_level => $logging_level,
    ticket_salt   => $ticket_salt,
    prepare_web   => $run_web,
  }

  include ::icinga2::feature::checker
  include ::icinga2::feature::notification

  ::icinga2::object::zone { $global_zones:
    global => true,
  }

  if $_config_server {
    if $web_api_pass {
      ::icinga2::object::apiuser { $web_api_user:
        password    => $web_api_pass,
        permissions => [ 'status/query', 'actions/*', 'objects/modify/*', 'objects/query/*' ],
        target      => "/etc/icinga2/zones.d/${zone}/api-users.conf",
      }
    }

    if $director_api_pass {
      ::icinga2::object::apiuser { $director_api_user:
        password    => $director_api_pass,
        permissions => [ '*' ],
        target      => "/etc/icinga2/zones.d/${zone}/api-users.conf",
      }
    }

    ($global_zones + keys($_workers) + $zone).each |String $dir| {
      file { "${::icinga2::globals::conf_dir}/zones.d/${dir}":
        ensure => directory,
        tag    => 'icinga2::config::file',
        owner  => $::icinga2::globals::user,
        group  => $::icinga2::globals::group,
        mode   => '0750',
      }
    }
  } else {
    file { "${::icinga2::globals::conf_dir}/zones.d":
      ensure  => directory,
      purge   => true,
      recurse => true,
      force   => true,
    }
  }

}
