# @summary
#   Manage repositories via `zypper`.
#
# @api private
#
class icinga::repos::zypper {
  assert_private()

  $repos   = $icinga::repos::list
  $managed = $icinga::repos::managed

  $repos.each |String $repo_name, Hash $repo_config| {
    if $repo_name in keys($managed) and $managed[$repo_name] {
      if $repo_config['proxy'] {
        $_proxy = "--httpproxy ${repo_config['proxy']}"
      } else {
        $_proxy = undef
      }

      exec { "import ${repo_name} gpg key":
        path      => '/bin:/usr/bin:/sbin:/usr/sbin',
        command   => "rpm ${_proxy} --import ${repo_config['gpgkey']}",
        unless    => 'rpm -q gpg-pubkey-34410682',
        logoutput => 'on_failure',
      }

      -> zypprepo { $repo_name:
        * => delete($repo_config, 'proxy'),
      }

      -> file_line { "add proxy settings to ${repo_name}":
        path => "/etc/zypp/repos.d/${repo_name}.repo",
        line => "proxy=${repo_config['proxy']}",
      }
      -> Package <| tag == 'icinga' or tag == 'icinga2' or tag == 'icingadb' or tag == 'icingaweb2' |>
    }
  }
}
