# @summary
#   This class exists to manage general configuration files needed by Icinga 2 to run.
#
# @api private
#
class icinga2::config {

  assert_private()

  $constants      = prefix($::icinga2::_constants, 'const ')
  $conf_dir       = $::icinga2::globals::conf_dir
  $user           = $::icinga2::globals::user
  $group          = $::icinga2::globals::group
  $plugins        = $::icinga2::plugins
  $confd          = $::icinga2::_confd
  $purge_features = $::icinga2::purge_features

  $template_constants  = icinga2::parse($constants)
  $template_mainconfig = template('icinga2/icinga2.conf.erb')
  $file_permissions    = '0640'

  File {
    owner => $user,
    group => $group,
    mode  => $file_permissions,
  }

  file { "${conf_dir}/constants.conf":
    ensure  => file,
    content => $template_constants,
  }

  file { "${conf_dir}/icinga2.conf":
    ensure  => file,
    content => $template_mainconfig,
  }

  file { "${conf_dir}/features-enabled":
    ensure  => directory,
    purge   => $purge_features,
    recurse => $purge_features,
  }

}
