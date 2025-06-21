# @summary
#   Manage repositories via `yum`.
#
# @api private
#
class icinga::repos::yum {
  assert_private()

  $repos   = $icinga::repos::list
  $managed = $icinga::repos::managed

  # EPEL package
  if !'epel' in keys($repos) and $managed['epel'] {
    warning("Repository EPEL isn't available on ${facts['os']['name']} ${facts['os']['release']['major']}.")
  }

  # PowerTools package
  if !'powertools' in keys($repos) and $managed['powertools'] {
    warning("Repository PowerTools isn't available on ${facts['os']['name']} ${facts['os']['release']['major']}.")
  }

  # CRB package
  if !'crb' in keys($repos) and $managed['crb'] {
    warning("Repository CRB isn't available on ${facts['os']['name']} ${facts['os']['release']['major']}.")
  }

  $repos.each |String $repo_name, Hash $repo_config| {
    if $repo_name in keys($managed) and $managed[$repo_name] {
      Yumrepo[$repo_name] -> Package <| tag == 'icinga' or tag == 'icinga2' or tag == 'icingadb' or tag == 'icingaweb2' |>
      yumrepo { $repo_name:
        * => $repo_config,
      }
    }
  }
}
