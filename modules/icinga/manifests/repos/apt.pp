# @summary
#   Manage repositories via `apt`.
#
# @api private
#
class icinga::repos::apt {
  assert_private()

  $repos   = $icinga::repos::list
  $managed = $icinga::repos::managed

  $configure_backports = $icinga::repos::configure_backports

  include apt

  if $configure_backports {
    include apt::backports
    Apt::Source['backports'] -> Package <| tag == 'icinga' or tag == 'icinga2' or tag == 'icingadb' or tag == 'icingaweb2' |>
  }

  $repos.each |String $repo_name, Hash $repo_config| {
    if $managed[$repo_name] {
      if $repo_config['key'] and !$repo_config['key']['id'] {
        ensure_resource('apt::keyring', $repo_config['key']['name'], $repo_config['key'])
        $_repo_config = $repo_config - 'key' + { 'keyring' => "/etc/apt/keyrings/${repo_config['key']['name']}" }
      } else {
        $_repo_config = $repo_config
      }

      Apt::Source[$repo_name] -> Package <| tag == 'icinga' or tag == 'icinga2' or tag == 'icingadb' or tag == 'icingaweb2' |>
      apt::source { $repo_name:
        * => { ensure => present } + $_repo_config,
      }
    }
  }
}
