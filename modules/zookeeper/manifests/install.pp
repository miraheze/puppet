# Class: zookeeper::install
#
# This module manages installation tasks.
#
# @private - do not use directly (use main `zookeeper` class).
class zookeeper::install inherits zookeeper {
  $os_family = $facts['os']['family']

  # Java installation
  if ($zookeeper::install_java) {
    if !$zookeeper::java_package {
      fail('Java installation is required, but no java package was provided.')
    }

    # Make sure the Java package is only installed once.
    ensure_resource('package', $zookeeper::java_package, {
        'ensure'        => $zookeeper::ensure,
        'allow_virtual' => true,
        'before'        => Class['zookeeper::post_install'],
      }
    )
  }

  # Package installation
  case $zookeeper::install_method {
    'archive': {
      contain zookeeper::install::archive

      Class['zookeeper::install::archive']
      -> Class['zookeeper::post_install']
    }
    'package': {
      # Repo management
      case $os_family {
        'RedHat', 'Suse': {
          contain zookeeper::install::repo

          Class['zookeeper::install::repo']
          -> Class['zookeeper::post_install']
        }
        default: {} # nothing to do
      }

      contain zookeeper::install::package
      Class['zookeeper::install::package']
      -> Class['zookeeper::post_install']
    }
    default: {
      fail('Valid installation methods are `package` or `archive`')
    }
  }

  # Post installation tasks
  contain zookeeper::post_install
}
