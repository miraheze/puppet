# @summary
#   Private define resource to used by this module only.
#
# @api private
#
define icinga2::feature(
  Enum['absent', 'present'] $ensure  = present,
  String                    $feature = $title,
) {

  assert_private()

  $user     = $::icinga2::globals::user
  $group    = $::icinga2::globals::group
  $conf_dir = $::icinga2::globals::conf_dir

  $_ensure = $ensure ? {
    'present' => link,
    default   => absent,
  }

  file { "${conf_dir}/features-enabled/${feature}.conf":
    ensure  => $_ensure,
    owner   => $user,
    group   => $group,
    target  => "../features-available/${feature}.conf",
    require => Concat["${conf_dir}/features-available/${feature}.conf"],
    notify  => Class['::icinga2::service'],
  }

}
