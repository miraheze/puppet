# @summary Configures chrony
#
# @api private
class chrony::config {
  assert_private()

  file { $chrony::config:
    ensure  => file,
    owner   => 0,
    group   => 0,
    mode    => $chrony::config_mode,
    content => epp($chrony::config_template,
      {
        servers => chrony::server_array_to_hash($chrony::servers, ['iburst']),
        pools   => chrony::server_array_to_hash($chrony::pools, ['iburst']),
        peers   => chrony::server_array_to_hash($chrony::peers),
      }
    ),
  }

  $chrony_password = $chrony::chrony_password.unwrap
  $keys_params = {
    'chrony_password' => $chrony_password,
    'commandkey' => $chrony::commandkey,
    'keys' => $chrony::keys,
  }

  unless empty($chrony::config_keys) {
    file { $chrony::config_keys:
      ensure  => file,
      replace => $chrony::config_keys_manage,
      owner   => $chrony::config_keys_owner,
      group   => $chrony::config_keys_group,
      mode    => $chrony::config_keys_mode,
      content => Sensitive(epp($chrony::config_keys_template, $keys_params)),
    }
  }

  if $chrony::options_file and $chrony::options {
    file { $chrony::options_file:
      ensure  => file,
      owner   => 0,
      group   => 0,
      mode    => '0644',
      content => epp($chrony::options_template),
    }
  }
}
