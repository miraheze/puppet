# @summary
#   Configures the Icinga 2 Core and the api feature.
#
# @api private
#
# @param ca
#   Enables a CA on this node.
#
# @param this_zone
#   Name of the Icinga zone.
#
# @param zones
#   All other zones.
#
# @param ca_server
#   The CA to send the certificate request to.
#
# @param ticket_salt
#   Set the constants `TicketSalt` if `ca` is set to `true`. Otherwise the set value is used
#   to authenticate the certificate request againt the CA on host `ca_server`.
#
# @param extra_packages
#   Install extra packages such as plugins.
#
# @param logging_type
#   Switch the log target. On Windows `syslog` is ignored, `eventlog` on all other platforms.
#
# @param logging_level
#   Set the log level.
#
# @param ssh_private_key
#   The private key to install.
#
# @param ssh_key_type
#   SSH key type.
#
# @param cert_name
#   The certificate name to set as constant NodeName.
#
# @param prepare_web
#   Prepare to run Icinga Web 2 on the same machine. Manage a group `icingaweb2`
#   and add the Icinga user to this group.
#
# @param confd
#   `conf.d` is the directory where Icinga 2 stores its object configuration by default. To enable it,
#   set this parameter to `true`. It's also possible to assign your own directory. This directory must be
#   managed outside of this module as file resource with tag icinga2::config::file.
#
class icinga (
  Boolean                                 $ca,
  String[1]                               $this_zone,
  Hash[String[1], Hash]                   $zones,
  String[1]                               $cert_name,
  Optional[Stdlib::Host]                  $ca_server       = undef,
  Optional[Icinga::Secret]                $ticket_salt     = undef,
  Array[String[1]]                        $extra_packages  = [],
  Enum['file', 'syslog', 'eventlog']      $logging_type    = 'file',
  Optional[Icinga::LogLevel]              $logging_level   = undef,
  Optional[Icinga::Secret]                $ssh_private_key = undef,
  Optional[Enum['ecdsa','ed25519','rsa']] $ssh_key_type    = undef,
  Boolean                                 $prepare_web     = false,
  Variant[Boolean, String[1]]             $confd           = false,
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

  class { 'icinga2':
    confd           => $confd,
    manage_packages => $manage_packages,
    constants       => lookup('icinga2::constants', undef, undef, {}) + $_constants,
    features        => [],
  }

  # check selinux
  $_selinux = if fact('os.selinux.enabled') and $facts['os']['selinux']['enabled'] and $icinga2::globals::selinux_package_name {
    $icinga2::manage_selinux
  } else {
    false
  }

  # switch logging between mainlog, syslog and eventlog
  if $facts['kernel'] != 'windows' {
    if $logging_type == 'file' {
      $_mainlog = 'present'
      $_syslog  = 'absent'
    } else {
      $_mainlog = 'absent'
      $_syslog  = 'present'
    }

    class { 'icinga2::feature::syslog':
      ensure   => $_syslog,
      severity => $logging_level,
    }
  } else {
    if $logging_type == 'file' {
      $_mainlog  = 'present'
      $_eventlog = 'absent'
    } else {
      $_mainlog  = 'absent'
      $_eventlog = 'present'
    }

    class { 'icinga2::feature::windowseventlog':
      ensure   => $_eventlog,
      severity => $logging_level,
    }
  }

  class { 'icinga2::feature::mainlog':
    ensure   => $_mainlog,
    severity => $logging_level,
  }

  case $facts['kernel'] {
    'linux': {
      $icinga_user     = $icinga2::globals::user
      $icinga_group    = $icinga2::globals::group
      $icinga_service  = $icinga2::globals::service_name
      $icinga_packages = if $_selinux {
        [$icinga2::globals::package_name, $icinga2::globals::selinux_package_name] + $extra_packages
      } else {
        [$icinga2::globals::package_name] + $extra_packages
      }

      case $facts['os']['family'] {
        'redhat': {
          $icinga_user_homedir = $icinga2::globals::spool_dir

          package { ['nagios-common'] + $icinga_packages:
            ensure => installed,
            before => Class['icinga2'],
          }

          -> group { 'nagios':
            members => [$icinga_user],
          }
        }

        'debian': {
          $icinga_user_homedir = '/var/lib/nagios'

          package { $icinga_packages:
            ensure => installed,
            before => Class['icinga2'],
          }
        }

        'suse': {
          $icinga_user_homedir = $icinga2::globals::spool_dir

          package { $icinga_packages:
            ensure => installed,
            before => Class['icinga2'],
          }
        }

        default: {
          fail("'Your operatingssystem ${::facts['os']['name']} is not supported'")
        }
      } # osfamily

      if $prepare_web {
        Package['icinga2'] -> Exec['restarting icinga2'] -> Class['icinga2']

        group { 'icingaweb2':
          system  => true,
          members => $icinga_user,
        }

        ~> exec { 'restarting icinga2':
          path        => $facts['path'],
          command     => "systemctl restart ${icinga_service}",
          onlyif      => "systemctl status ${icinga_service}",
          refreshonly => true,
        }
      } # prepare_web

      if $ssh_private_key {
        unless $ssh_key_type { fail('parameter ssh_key_typ must set') }

        file {
          default:
            ensure  => file,
            owner   => $icinga_user,
            group   => $icinga_group,
            seltype => 'icinga2_spool_t',
            require => Package[$icinga_packages];
          ["${icinga_user_homedir}/.ssh", "${icinga_user_homedir}/.ssh/controlmasters"]:
            ensure => directory,
            mode   => '0700';
          "${icinga_user_homedir}/.ssh/id_${ssh_key_type}":
            mode      => '0600',
            show_diff => false,
            content   => unwrap($ssh_private_key);
          "${icinga_user_homedir}/.ssh/config":
            content => "Host *\n  StrictHostKeyChecking no\n  ControlPath ~${icinga_user}/.ssh/controlmasters/%r@%h:%p.socket\n  ControlMaster auto\n  ControlPersist 5m";
        }
      } # privkey
    } # Linux

    'windows': {
      $manage_repo = false

      if $logging_type == 'syslog' {
        fail('Only eventlog and file is supported as logging_type on Windows')
      }
    }

    default: {
      fail("'Your operatingssystem ${facts[os][name]} is not supported'")
    }
  } # kernel

  if $ca {
    include icinga2::pki::ca

    class { 'icinga2::feature::api':
      pki             => 'none',
      accept_config   => true,
      accept_commands => true,
      ticket_salt     => 'TicketSalt',
      zones           => {},
      endpoints       => {},
    }
  } else {
    if $ca_server {
      class { 'icinga2::feature::api':
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
          icinga2::object::endpoint { $endpoint:
            * => $endpoint_attrs,
          }
        }
      } # endpoints
    }

    icinga2::object::zone { $zone:
      * => $zone_attrs + { 'endpoints' => keys($zone_attrs['endpoints']) },
    }
  }
}
