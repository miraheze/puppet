# Defining class to add debian security mirror to apt
class apt::security (
  Optional[String] $location                    = 'http://security.debian.org/',
  Optional[String] $release                     = undef,
  Optional[String] $repos                       = 'main',
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
  if ($facts['os']['name'] == 'Debian' or $facts['os']['name'] == 'Ubuntu') {
    if os_version('debian >= bullseye') {
      $securityDist = '-security'
    } else {
      $securityDist = ''
    }
    unless $location {
      $_location = $::apt::security['location']
    }
    unless $release {
      $_release = "${facts['os']['distro']['codename']}${securityDist}/updates"
    }
    unless $repos {
      $_repos = $::apt::security['repos']
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
    key      => undef,
    pin      => $_pin,
  }
}
