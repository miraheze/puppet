# Class: zookeeper::post_install
#
# In order to maintain compatibility with older releases, there are
# some post-install task to ensure same behaviour on all platforms.
#
# PRIVATE CLASS - do not use directly (use main `zookeeper` class).
class zookeeper::post_install inherits zookeeper {
  if ($zookeeper::manual_clean) {
    # User defined value
    $_clean = $zookeeper::manual_clean
  } else {
    $_clean = false
  }

  # If !$cleanup_count, then ensure this cron is absent.
  if ($_clean and $zookeeper::snap_retain_count > 0 and $zookeeper::ensure != 'absent') {
    if ($zookeeper::ensure_cron) {
      include cron

      cron::job { 'zookeeper-cleanup':
        ensure  => present,
        command => "${zookeeper::cleanup_sh} ${zookeeper::datastore} ${zookeeper::snap_retain_count}",
        hour    => 2,
        minute  => 42,
        user    => $zookeeper::user,
      }
    } else {
      file { '/etc/cron.daily/zkcleanup':
        ensure  => file,
        content => "${zookeeper::cleanup_sh} ${zookeeper::datastore} ${zookeeper::snap_retain_count}",
      }
    }
  }

  # Package removal
  if ($_clean and $zookeeper::ensure == 'absent') {
    if ($zookeeper::ensure_cron) {
      class { 'cron':
        manage_package => false,
      }

      cron::job { 'zookeeper-cleanup':
        ensure => $zookeeper::ensure,
      }
    } else {
      file { '/etc/cron.daily/zkcleanup':
        ensure => $zookeeper::ensure,
      }
    }
  }
}
