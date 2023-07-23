# @summary
#   Configures the Icinga 2 Core and the api feature.
#
# @api private
#
# @param [Boolean] ca
#   Enables a CA on this node.
#
# @param [String] this_zone
#   Name of the Icinga zone.
#
# @param [Hash[String, Hash]] zones
#   All other zones.
#
# @param [Enum['dsa','ecdsa','ed25519','rsa']] ssh_key_type
#   SSH key type.
#
# @param [Optional[String]] ssh_private_key
#   The private key to install.
#
# @param [Optional[String]] ssh_public_key
#   The public key to install.
#
# @param [Optional[Stdlib::Host]] ca_server
#   The CA to send the certificate request to.
#
# @param [Optional[String]] ticket_salt
#   Set the constants `TicketSalt` if `ca` is set to `true`. Otherwise the set value is used
#   to authenticate the certificate request againt the CA on host `ca_server`.
#
# @param [Enum['file', 'syslog']] logging_type
#   Switch the log target. Only `file` is supported on Windows.
#
# @param [Optional[Icinga::LogLevel]] logging_level
#   Set the log level.
#
# @param [String] cert_name
#   The certificate name to set as constant NodeName.
#
# @param [Boolean] prepare_web
#   Prepare to run Icinga Web 2 on the same machine. Manage a group `icingaweb2`
#   and add the Icinga user to this group.
#
class icinga(
  Boolean                              $ca,
  String                               $this_zone,
  Hash[String, Hash]                   $zones,
  Enum['dsa','ecdsa','ed25519','rsa']  $ssh_key_type    = 'rsa',
  Optional[String]                     $ssh_private_key = undef,
  Optional[String]                     $ssh_public_key  = undef,
  Optional[Stdlib::Host]               $ca_server       = undef,
  Optional[String]                     $ticket_salt     = undef,
  Array[String]                        $extra_packages  = [],
  Enum['file', 'syslog']               $logging_type    = 'file',
  Optional[Icinga::LogLevel]           $logging_level   = undef,
  String                               $cert_name       = $facts['networking']['fqdn'],
  Boolean                              $prepare_web     = false,
) {

  assert_private()

  # CA uses const TicketSalt to set the ticket salt
  if $ca {
    if $ticket_salt {
      $_constants = { 'TicketSalt' => $ticket_salt, 'ZoneName' => $this_zone, 'NodeName' => $cert_name }
    } else {
      fail("Class[Icinga]: parameter 'ticket_salt' expects a String value if a CA is configured, got Undef")
    }
  } else {
    $_constants = { 'ZoneName' => $this_zone, 'NodeName' => $cert_name }
  }

  $manage_packages = $facts[os][family] ? {
    'redhat'  => false,
    'debian'  => false,
    'windows' => lookup('icinga2::manage_packages', undef, undef, true),
    'suse'    => false,
    default   => true,
  }

  class { '::icinga2':
    confd           => false,
    manage_packages => $manage_packages,
    constants       => lookup('icinga2::constants', undef, undef, {}) + $_constants,
    features        => [],
  }

  # switch logging between mainlog and syslog
  # logging on windows only file is supported, warning output see below
  if $logging_type == 'file' or $::kernel == 'windows' {
    $_mainlog = 'present'
    $_syslog  = 'absent'
  } else {
    $_mainlog = 'absent'
    $_syslog  = 'present'
  }

  class { '::icinga2::feature::mainlog':
    ensure   => $_mainlog,
    severity => $logging_level,
  }

  class { '::icinga2::feature::syslog':
    ensure   => $_syslog,
    severity => $logging_level,
  }

  case $::kernel {
    'linux': {
      $icinga_user    = $::icinga2::globals::user
      $icinga_group   = $::icinga2::globals::group
      $icinga_package = $::icinga2::globals::package_name
      $icinga_home    = $::icinga2::globals::spool_dir
      $icinga_service = $::icinga2::globals::service_name

      if $ssh_public_key {
        $icinga_shell = '/bin/bash'
      } else {
        $icinga_shell = '/bin/false'
      }

      case $::osfamily {
        'redhat': {
          package { [ 'nagios-common', $icinga_package ]+$extra_packages:
            ensure => installed,
            before => User[$icinga_user],
          }

          $icinga_user_groups = if $prepare_web { ['nagios', 'icingaweb2'] } else { ['nagios'] }
        } # RedHat

        'debian': {
          package { [$icinga_package]+$extra_packages:
            ensure => installed,
            before => User['nagios'],
          }

          $icinga_user_groups = if $prepare_web { ['icingaweb2'] } else { undef }
        } # Debian

        'suse': {
          package { [$icinga_package]+$extra_packages:
            ensure => installed,
            before => User['icinga'],
          }

          $icinga_user_groups = if $prepare_web { ['icingaweb2'] } else { undef }
        } # Suse

        default: {
          fail("'Your operatingssystem ${::facts[os][name]} is not supported'")
        }
      } # osfamily

      if $prepare_web {
        group { 'icingaweb2':
          system => true,
        }

        Package['icinga2'] -> Exec['restarting icinga2'] -> Class['icinga2']

        exec { 'restarting icinga2':
          path        => $::facts['path'],
          command     => "service ${icinga_service} restart",
          onlyif      => "service ${icinga_service} status",
          refreshonly => true,
          subscribe   => User[$icinga_user],
        }
      }

      user { $icinga_user:
        ensure => present,
        shell  => $icinga_shell,
        groups => $icinga_user_groups,
        before => Class['icinga2'],
      }

      if $ssh_public_key {
        ssh_authorized_key { "${icinga_user}@${::fqdn}":
          ensure => present,
          user   => $icinga_user,
          key    => $ssh_public_key,
          type   => $ssh_key_type,
        }
      } # pubkey

      if $ssh_private_key {
        file {
          default:
            ensure => file,
            owner  => $icinga_user,
            group  => $icinga_group;
          ["${icinga_home}/.ssh", "${icinga_home}/.ssh/controlmasters"]:
            ensure => directory,
            mode   => '0700';
          "${icinga_home}/.ssh/id_${ssh_key_type}":
            mode    => '0600',
            content => $ssh_private_key;
          "${icinga_home}/.ssh/config":
            content => "Host *\n  StrictHostKeyChecking no\n  ControlPath ${icinga_home}/.ssh/controlmasters/%r@%h:%p.socket\n  ControlMaster auto\n  ControlPersist 5m";
        }
      } # privkey
    } # Linux

    'windows': {
      $manage_repo = false

      if $logging_type != 'file' {
        warning('Only file is support as logging_type on Windows')
      }
    }

    default: {
      fail("'Your operatingssystem ${::facts[os][name]} is not supported'")
    }
  } # kernel

  if $ca {
    include ::icinga2::pki::ca

    class { '::icinga2::feature::api':
      pki             => 'none',
      accept_config   => true,
      accept_commands => true,
      ticket_salt     => 'TicketSalt',
      zones           => {},
      endpoints       => {},
    }
  } else {
    if $ca_server {
      class { '::icinga2::feature::api':
        accept_config   => true,
        accept_commands => true,
        ca_host         => $ca_server,
        ticket_salt     => $ticket_salt,
        zones           => {},
        endpoints       => {},
      }
    }
  }

  $zones.each |String $zone, Hash $zone_attrs| {
    $zone_attrs.each|String $attr, $value| {
      if $attr == 'endpoints' {
        $value.each |String $endpoint, Hash $endpoint_attrs| {
          ::icinga2::object::endpoint { $endpoint:
            * => $endpoint_attrs,
          }
        }
      } # endpoints
    }
    ::icinga2::object::zone { $zone:
      * => $zone_attrs + { 'endpoints' => keys($zone_attrs['endpoints']) }
    }
  }

}
