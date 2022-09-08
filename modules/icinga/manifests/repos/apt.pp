# @summary
#   Manage repositories via `apt`.
#
# @api private
#
class icinga::repos::apt {

  assert_private()

  $repos   = $::icinga::repos::list
  $managed = $::icinga::repos::managed

  $configure_backports = $::icinga::repos::configure_backports

  include ::apt

  $http_proxy = lookup('http_proxy', {'default_value' => undef})
  if $http_proxy {
    file { '/etc/apt/apt.conf.d/01icinga':
      ensure  => present,
      content => template('icinga/apt/01icinga.erb'),
      before  => Apt::Source['icinga-stable-release'],
    }
  }

  if $configure_backports {
    include ::apt::backports
    Apt::Source['backports'] -> Package <| title != 'apt-transport-https' |>
  }

  # fix issue 21, 33
  file { ['/etc/apt/sources.list.d/netways-plugins.list', '/etc/apt/sources.list.d/netways-extras.list']:
    ensure => 'absent',
  }

  $repos.each |String $repo_name, Hash $repo_config| {
    if $managed[$repo_name] {
      Apt::Source[$repo_name] -> Package <| title != 'apt-transport-https' |>
      apt::source { $repo_name:
        *       =>  merge({ ensure => present }, $repo_config),
        require => File['/etc/apt/sources.list.d/netways-plugins.list', '/etc/apt/sources.list.d/netways-extras.list'],
      }
    }
  }

}
