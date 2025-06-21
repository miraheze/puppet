# @summary
#   Setup an agentless monitoring via SSH.
#
# @param user
#   User name to login.
#
# @param manage_user
#   Wether or not to manage user.
#
# @param ssh_key_type
#   SSH key type.
#
# @param ssh_public_key
#   Public SSH key of ´ssh_key_type´ for ´user´.
#
# @param extra_packages
#   Install extra packages such as plugins.
#
class icinga::agentless (
  String[1]                     $user,
  Boolean                       $manage_user,
  Enum['ecdsa','ed25519','rsa'] $ssh_key_type,
  String[1]                     $ssh_public_key,
  Array[String[1]]              $extra_packages = [],
) {
  if defined(Class['icinga']) {
    if $user != $icinga2::globals::user {
      $user_name  = $user
      $user_group = undef
      $user_home  = "/home/${user}"
    } else {
      $user_name  = $icinga2::globals::user
      $user_group = $icinga2::globals::group
      $user_home  = $icinga::icinga_user_homedir

      file { "/home/${user}":
        ensure  => absent,
        recurse => true,
        force   => true,
      }
    }

    if $manage_user { User[$user_name] -> Package[$icinga2::globals::package_name] }
    Package[$icinga2::globals::package_name] -> Ssh_authorized_key["${user_name}@${$facts['networking']['fqdn']}"]
  } else {
    $user_name  = $user
    $user_group = if $facts['os']['family'] != 'suse' { undef } else { $user }
    $user_home  = "/home/${user}"
  }

  if $manage_user {
    if $facts['os']['family'] == 'suse' {
      group { $user_group:
        system => true,
      }
    }

    user { $user_name:
      ensure     => present,
      gid        => $user_group,
      system     => true,
      managehome => true,
      home       => $user_home,
      shell      => '/bin/bash',
    }
  }

  ssh_authorized_key { "${user_name}@${$facts['networking']['fqdn']}":
    ensure => present,
    user   => $user_name,
    key    => $ssh_public_key,
    type   => $ssh_key_type,
  }

  if versioncmp(load_module_metadata('stdlib')['version'], '9.0.0') < 0 {
    ensure_packages($extra_packages, { 'ensure' => 'present' })
  } else {
    stdlib::ensure_packages($extra_packages, { 'ensure' => 'present' })
  }
}
