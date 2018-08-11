# Defining class to add debian security mirror to apt
class apt::secuirty (
  Optional[String] $location                    = 'http://security.debian.org/',
  Optional[String] $release                     = undef,
  Optional[String] $repos                       = 'main',
  Optional[Variant[String, Hash]] $key          = undef,
  Optional[Variant[Integer, String, Hash]] $pin = 200,
){
  if $location {
    $_location = $location
  }
  if $release {
    $_release = $release
  }
  if $repos {
    $_repos = $repos
  }
  if $key {
    $_key = $key
  }
  if ($facts['lsbdistid'] == 'Debian' or $facts['lsbdistid'] == 'Ubuntu') {
    unless $location {
      $_location = $::apt::backports['location']
    }
    unless $release {
      $_release = "${facts['lsbdistcodename']}/updates"
    }
    unless $repos {
      $_repos = $::apt::backports['repos']
    }
    unless $key {
      $_key =  $::apt::backports['key']
    }
  } else {
    unless $location and $release and $repos and $key {
      fail('If not on Debian or Ubuntu, you must explicitly pass location, release, repos, and key')
    }
  }

  if $pin =~ Hash {
    $_pin = $pin
  } elsif $pin =~ Numeric or $pin =~ String {
    # apt::source defaults to pinning to origin, but we should pin to release
    # for backports
    $_pin = {
      'priority' => $pin,
      'release'  => $_release,
    }
  } else {
    fail('pin must be either a string, number or hash')
  }

  apt::source { 'debian_security':
    location => $_location,
    release  => $_release,
    repos    => $_repos,
    key      => $_key,
    pin      => $_pin,
  }
}
