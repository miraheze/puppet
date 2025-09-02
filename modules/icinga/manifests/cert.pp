# @summary
#   A class to generate tls key, cert and cacert files.
#
# @param args
#   A config hash with the keys:
#   key_file, cert_file, cacert_file, key, cert and cacert
#
# @param owner
#   Owner of the files.
#
# @param group
#   Group membership of all files.
#
define icinga::cert (
  Icinga::Certificate $args,
  String[1]           $owner,
  String[1]           $group,
) {
  if $facts['os']['family'] == 'windows' {
    $key_mode = undef
  } else {
    File {
      owner => $owner,
      group => $group,
      mode  => '0640',
    }
    $key_mode = '0440'
  }

  if $args[key] {
    file { $args['key_file']:
      ensure    => file,
      content   => icinga::newline(unwrap($args['key'])),
      mode      => $key_mode,
      show_diff => false,
    }
  }

  if $args['cert'] {
    file { $args['cert_file']:
      ensure  => file,
      content => icinga::newline($args['cert']),
    }
  }

  if $args['cacert'] {
    file { $args['cacert_file']:
      ensure  => file,
      content => icinga::newline($args['cacert']),
    }
  }
}
