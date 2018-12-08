# == Define: icinga2::config::fragment
#
# Set a code fragment in a target configuration file.
#
# === Parameters
#
# [*content*]
#   Content to insert in file specified in target.
#
# [*target*]
#   Destination config file to store in this fragment. File will be declared the
#   first time.
#
# [*order*]
#   String or integer to set the position in the target file, sorted in alpha numeric order. Defaults to `00`.
#
#
define icinga2::config::fragment(
  String                       $content,
  Stdlib::Absolutepath         $target,
  String                       $code_name = $title,
  Variant[String, Integer]     $order     = '00',
) {

  Concat {
    owner => $::icinga2::globals::user,
    group => $::icinga2::globals::group,
    mode  => '0640',
  }
  $_content = $content

  if !defined(Concat[$target]) {
    concat { $target:
      ensure => present,
      tag    => 'icinga2::config::file',
      warn   => true,
    }
  }

  concat::fragment { "icinga2::config::${code_name}":
    target  => $target,
    content => $_content,
    order   => $order,
  }

}
