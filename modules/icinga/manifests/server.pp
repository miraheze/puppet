# @summary
#   Setup a Icinga server.
#
# @param ca
#   Enables a CA on this node.
#
# @param config_server
#   Enables that this node is the central configuration server.
#
# @param zone
#   Name of the Icinga zone.
#
# @param colocation_endpoints
#   When the zone includes more than one endpoint, set here the additional endpoint(s).
#   Icinga supports two endpoints per zone only.
#
# @param workers
#   All worker zones with key 'endpoints' for endpoint objects.
#
# @param global_zones
#   List of global zones to configure.
#
# @param ca_server
#   The CA to send the certificate request to.
#
# @param ticket_salt
#   Set an alternate ticket salt to icinga::ticket_salt from Hiera.
#
# @param web_api_user
#   Icinga API user to connect Icinga 2. Notice: user is only created if a password is set.
#
# @param web_api_pass
#   Icinga API user password.
#
# @param director_api_user
#   Icinga API director user to connect Icinga 2. Notice: user is only created if a password is set.
#
# @param director_api_pass
#   Icinga API director user password.
#
# @param logging_type
#   Switch the log target. On Windows `syslog` is ignored, `eventlog` on all other platforms.
#
# @param logging_level
#   Set the log level.
#
# @param run_web
#   Prepare to run Icinga Web 2 on the same machine. Manage a group `icingaweb2`
#   and add the Icinga user to this group.
#
# @param ssh_private_key
#   The private key to install.
#
# @param ssh_key_type
#   SSH key type.
#
class icinga::server (
  Enum['file', 'syslog', 'eventlog'] $logging_type,
  Icinga::LogLevel                   $logging_level,
  Boolean                            $ca                   = false,
  Boolean                            $config_server        = false,
  String[1]                          $zone                 = 'main',
  Hash[String[1], Hash]              $colocation_endpoints = {},
  Hash[String[1], Hash]              $workers              = {},
  Array[String[1]]                   $global_zones         = [],
  Optional[Stdlib::Host]             $ca_server            = undef,
  Optional[Icinga::Secret]           $ticket_salt          = undef,
  String[1]                          $web_api_user         = 'icingaweb2',
  Optional[Icinga::Secret]           $web_api_pass         = undef,
  String[1]                          $director_api_user    = 'director',
  Optional[Icinga::Secret]           $director_api_pass    = undef,
  Boolean                            $run_web              = false,
  Enum['ecdsa','ed25519','rsa']      $ssh_key_type         = rsa,
  Optional[Icinga::Secret]           $ssh_private_key      = undef,
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

  # inject parent zone if no parent exists
  $_workers = $workers.reduce({}) |$memo, $worker| { $memo + { $worker[0] => { parent => $zone } + $worker[1] } }

  class { 'icinga':
    ca              => $_ca,
    ca_server       => $ca_server,
    this_zone       => $zone,
    zones           => { 'ZoneName' => { 'endpoints' => { 'NodeName' => {} } + $colocation_endpoints } } + $_workers,
    ssh_private_key => $ssh_private_key,
    ssh_key_type    => $ssh_key_type,
    logging_type    => $logging_type,
    logging_level   => $logging_level,
    ticket_salt     => $ticket_salt,
    prepare_web     => $run_web,
  }

  include icinga2::feature::checker
  include icinga2::feature::notification

  icinga2::object::zone { $global_zones:
    global => true,
    order  => 'zz',
  }

  if $_config_server {
    if $web_api_pass {
      icinga2::object::apiuser { $web_api_user:
        password    => $web_api_pass,
        permissions => ['status/query', 'actions/*', 'objects/modify/*', 'objects/query/*'],
        target      => "/etc/icinga2/zones.d/${zone}/api-users.conf",
      }
    }

    if $director_api_pass {
      icinga2::object::apiuser { $director_api_user:
        password    => $director_api_pass,
        permissions => ['*'],
        target      => "/etc/icinga2/zones.d/${zone}/api-users.conf",
      }
    }

    ($global_zones + keys($_workers) + $zone).each |String $dir| {
      file { "${icinga2::globals::conf_dir}/zones.d/${dir}":
        ensure  => directory,
        tag     => 'icinga2::config::file',
        owner   => $icinga2::globals::user,
        group   => $icinga2::globals::group,
        mode    => '0750',
        seltype => 'icinga2_etc_t',
      }
    }
  } else {
    file { "${icinga2::globals::conf_dir}/zones.d":
      ensure  => directory,
      purge   => true,
      recurse => true,
      force   => true,
      seltype => 'icinga2_etc_t',
    }
  }
}
