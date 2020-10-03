#
class syslog_ng::reload (
  $syntax_check_before_reloads = true
) {

  include syslog_ng

  $config_file     = $::syslog_ng::config_file
  $exec_path = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:'

  $syslog_ng_ctl_full_path = "${::syslog_ng::sbin_path}/syslog-ng-ctl"
  $syslog_ng_full_path = "${::syslog_ng::sbin_path}/syslog-ng"

  $syslog_ng_syntax_check_cmd = "${syslog_ng_full_path} --syntax-only --cfgfile %"

  notice("syslog_ng::reload: syntax_check_before_reloads=${syntax_check_before_reloads}")

  exec { 'syslog_ng_reload':
    command     => "${syslog_ng_ctl_full_path} reload",
    path        => $exec_path,
    refreshonly => true,
    try_sleep   => 1,
    logoutput   => true,
    require     => Service[$::syslog_ng::service_name],
  }

  if $syntax_check_before_reloads {
    Concat <| title == $config_file |> { validate_cmd => $syslog_ng_syntax_check_cmd }
  } else {
    Concat <| title == $config_file |>
  }
  Concat[$config_file] ~> Exec['syslog_ng_reload']
}
