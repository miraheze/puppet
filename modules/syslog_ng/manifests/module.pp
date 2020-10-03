#
define syslog_ng::module {
  include ::syslog_ng
  $module_prefix = $::syslog_ng::module_prefix
  package { "${module_prefix}${title}":
    ensure => $::syslog_ng::package_ensure
  }
}
