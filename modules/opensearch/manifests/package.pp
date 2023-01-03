# This class exists to coordinate all software package management related
# actions, functionality and logical units in a central place.
#
# It is not intended to be used directly by external resources like node
# definitions or other modules.
#
# @example importing this class by other classes to use its functionality:
#   class { 'opensearch::package': }
#
# @author Richard Pijnenburg <richard.pijnenburg@elasticsearch.com>
# @author Tyler Langlois <tyler.langlois@elastic.co>
#
class opensearch::package {
  Exec {
    path      => ['/bin', '/usr/bin', '/usr/local/bin'],
    cwd       => '/',
    tries     => 3,
    try_sleep => 10,
  }

  if $opensearch::ensure == 'present' {
    if $opensearch::restart_package_change {
      Package['opensearch'] ~> Class['opensearch::service']
    }

    # Create directory to place the package file
    $package_dir = $opensearch::package_dir
    exec { 'create_package_dir_opensearch':
      cwd     => '/',
      path    => ['/usr/bin', '/bin'],
      command => "mkdir -p ${package_dir}",
      creates => $package_dir,
    }

    file { $package_dir:
      ensure  => 'directory',
      purge   => $opensearch::purge_package_dir,
      force   => $opensearch::purge_package_dir,
      backup  => false,
      require => Exec['create_package_dir_opensearch'],
    }

    # Check if we want to install a specific version or not
    if $opensearch::version == false {
      $package_ensure = $opensearch::autoupgrade ? {
        true  => 'latest',
        false => 'present',
      }
    } else {
      # install specific version
      $package_ensure = $opensearch::pkg_version
    }

    # action
    if ($opensearch::package_url != undef) {
      case $opensearch::package_provider {
        'package': { $before = Package['opensearch'] }
        default:   { fail("software provider \"${opensearch::package_provider}\".") }
      }

      $filename_array = split($opensearch::package_url, '/')
      $basefilename = $filename_array[-1]

      $source_array = split($opensearch::package_url, ':')
      $protocol_type = $source_array[0]

      $ext_array = split($basefilename, '\.')
      $ext = $ext_array[-1]

      $pkg_source = "${package_dir}/${basefilename}"

      case $protocol_type {
        'puppet': {
          file { $pkg_source:
            ensure  => file,
            source  => $opensearch::package_url,
            require => File[$package_dir],
            backup  => false,
            before  => $before,
          }
        }
        'ftp', 'https', 'http': {
          if $opensearch::proxy_url != undef {
            $exec_environment = [
              'use_proxy=yes',
              "http_proxy=${opensearch::proxy_url}",
              "https_proxy=${opensearch::proxy_url}",
            ]
          } else {
            $exec_environment = []
          }

          case $opensearch::download_tool {
            String: {
              $_download_command = if $opensearch::download_tool_verify_certificates {
                $opensearch::download_tool
              } else {
                $opensearch::download_tool_insecure
              }

              exec { 'download_package_opensearch':
                command     => "${_download_command} ${pkg_source} ${opensearch::package_url} 2> /dev/null",
                creates     => $pkg_source,
                environment => $exec_environment,
                timeout     => $opensearch::package_dl_timeout,
                require     => File[$package_dir],
                before      => $before,
              }
            }
            default: {
              fail("no \$opensearch::download_tool defined for ${facts['os']['family']}")
            }
          }
        }
        'file': {
          $source_path = $source_array[1]
          file { $pkg_source:
            ensure  => file,
            source  => $source_path,
            require => File[$package_dir],
            backup  => false,
            before  => $before,
          }
        }
        default: {
          fail("Protocol must be puppet, file, http, https, or ftp. You have given \"${protocol_type}\"")
        }
      }

      if ($opensearch::package_provider == 'package') {
        case $ext {
          'deb':   { Package { provider => 'dpkg', source => $pkg_source } }
          'rpm':   { Package { provider => 'rpm', source => $pkg_source } }
          default: { fail("Unknown file extention \"${ext}\".") }
        }
      }
    } else {
      if ($opensearch::manage_repo and $facts['os']['family'] == 'Debian') {
        Class['apt::update'] -> Package['opensearch']
      }
    }
  } else {
    # Package removal
    if ($facts['os']['family'] == 'Suse') {
      Package {
        provider  => 'rpm',
      }
      $package_ensure = 'absent'
    } else {
      $package_ensure = 'purged'
    }
  }

  if ($opensearch::package_provider == 'package') {
    package { 'opensearch':
      ensure => $package_ensure,
      name   => $opensearch::package_name,
    }
  } else {
    fail("\"${opensearch::package_provider}\" is not supported")
  }
}
