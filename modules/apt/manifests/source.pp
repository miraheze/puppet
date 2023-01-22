# @summary Manages the Apt sources in /etc/apt/sources.list.d/.
#
# @example Install the puppetlabs apt source
#   apt::source { 'puppetlabs':
#     location => 'http://apt.puppetlabs.com',
#     repos    => 'main',
#     key      => {
#       id     => '6F6B15509CF8E59E6E469F327F438280EF8D349F',
#       server => 'keyserver.ubuntu.com',
#     },
#   }
#
# @param location
#   Required, unless ensure is set to 'absent'. Specifies an Apt repository. Valid options: a string containing a repository URL.
#
# @param comment
#   Supplies a comment for adding to the Apt source file.
#
# @param ensure
#   Specifies whether the Apt source file should exist. Valid options: 'present' and 'absent'.
#
# @param release
#   Specifies a distribution of the Apt repository.
#
# @param repos
#   Specifies a component of the Apt repository.
#
# @param include
#   Configures include options. Valid options: a hash of available keys.
#
# @option include [Boolean] :deb
#   Specifies whether to request the distribution's compiled binaries. Default true.
#
# @option include [Boolean] :src
#   Specifies whether to request the distribution's uncompiled source code. Default false.
#
# @param key
#   Creates a declaration of the apt::key defined type. Valid options: a string to be passed to the `id` parameter of the `apt::key`
#   defined type, or a hash of `parameter => value` pairs to be passed to `apt::key`'s `id`, `server`, `content`, `source`, `weak_ssl`,
#   and/or `options` parameters.
#
# @param keyring
#   Absolute path to a file containing the PGP keyring used to sign this repository. Value is used to set signed-by on the source entry.
#   See https://wiki.debian.org/DebianRepository/UseThirdParty for details.
#
# @param pin
#   Creates a declaration of the apt::pin defined type. Valid options: a number or string to be passed to the `id` parameter of the
#   `apt::pin` defined type, or a hash of `parameter => value` pairs to be passed to `apt::pin`'s corresponding parameters.
#
# @param architecture
#   Tells Apt to only download information for specified architectures. Valid options: a string containing one or more architecture names,
#   separated by commas (e.g., 'i386' or 'i386,alpha,powerpc'). Default: undef (if unspecified, Apt downloads information for all architectures
#   defined in the Apt::Architectures option).
#
# @param allow_unsigned
#   Specifies whether to authenticate packages from this release, even if the Release file is not signed or the signature can't be checked.
#
# @param allow_insecure
#   Specifies whether to allow downloads from insecure repositories.
#
# @param notify_update
#   Specifies whether to trigger an `apt-get update` run.
#
# @param check_valid_until
#   Specifies whether to check if the package release date is valid. Defaults to `True`.
#
define apt::source (
  Optional[String] $location                    = undef,
  String $comment                               = $name,
  String $ensure                                = present,
  Optional[String] $release                     = undef,
  String $repos                                 = 'main',
  Variant[Hash] $include                        = {},
  Optional[Variant[String, Hash]] $key          = undef,
  Optional[Stdlib::AbsolutePath] $keyring       = undef,
  Optional[Variant[Hash, Numeric, String]] $pin = undef,
  Optional[String] $architecture                = undef,
  Boolean $allow_unsigned                       = false,
  Boolean $allow_insecure                       = false,
  Boolean $notify_update                        = true,
  Boolean $check_valid_until                    = true,
) {
  include apt

  $_before = Apt::Setting["list-${title}"]

  if !$release {
    if fact('os.distro.codename') {
      $_release = fact('os.distro.codename')
    } else {
      fail('os.distro.codename fact not available: release parameter required')
    }
  } else {
    $_release = $release
  }

  if $ensure == 'present' {
    if ! $location {
      fail('cannot create a source entry without specifying a location')
    }
    elsif ($apt::proxy['https_acng']) and ($location =~ /(?i:^https:\/\/)/) {
      $_location = regsubst($location, 'https://','http://HTTPS///')
    }
    else {
      $_location = $location
    }
    # Newer oses, do not need the package for HTTPS transport.
    $_transport_https_releases = ['9']
    if (fact('os.release.major') in $_transport_https_releases) and $_location =~ /(?i:^https:\/\/)/ {
      ensure_packages('apt-transport-https')
      Package['apt-transport-https'] -> Class['apt::update']
    }
  } else {
    $_location = undef
  }

  $includes = merge($apt::include_defaults, $include)

  if $key and $keyring {
    fail('parameters key and keyring are mutualy exclusive')
  }

  if $key {
    if $key =~ Hash {
      unless $key['id'] {
        fail('key hash must contain at least an id entry')
      }
      $_key = merge($apt::source_key_defaults, $key)
    } else {
      $_key = { 'id' => assert_type(String[1], $key) }
    }
  }

  $header = epp('apt/_header.epp')

  if $architecture {
    $_architecture = regsubst($architecture, '\baarch64\b', 'arm64')
  } else {
    $_architecture = undef
  }

  $sourcelist = epp('apt/source.list.epp', {
      'comment'          => $comment,
      'includes'         => $includes,
      'options'          => delete_undef_values({
          'arch'              => $architecture,
          'trusted'           => $allow_unsigned ? { true => 'yes', false => undef },
          'allow-insecure'    => $allow_insecure ? { true => 'yes', false => undef },
          'signed-by'         => $keyring,
          'check-valid-until' => $check_valid_until? { true => undef, false => 'false' },
        },
      ),
      'location'         => $_location,
      'release'          => $_release,
      'repos'            => $repos,
    }
  )

  apt::setting { "list-${name}":
    ensure        => $ensure,
    content       => "${header}${sourcelist}",
    notify_update => $notify_update,
  }

  if $pin {
    if $pin =~ Hash {
      $_pin = merge($pin, { 'ensure' => $ensure, 'before' => $_before })
    } elsif ($pin =~ Numeric or $pin =~ String) {
      $url_split = split($location, '[:\/]+')
      $host      = $url_split[1]
      $_pin = {
        'ensure'   => $ensure,
        'priority' => $pin,
        'before'   => $_before,
        'origin'   => $host,
      }
    } else {
      fail('Received invalid value for pin parameter')
    }
    create_resources('apt::pin', { "${name}" => $_pin })
  }

  # We do not want to remove keys when the source is absent.
  if $key and ($ensure == 'present') {
    if $_key =~ Hash {
      if $_key['ensure'] != undef {
        $_ensure = $_key['ensure']
      } else {
        $_ensure = $ensure
      }

      apt::key { "Add key: ${$_key['id']} from Apt::Source ${title}":
        ensure   => $_ensure,
        id       => $_key['id'],
        server   => $_key['server'],
        content  => $_key['content'],
        source   => $_key['source'],
        options  => $_key['options'],
        weak_ssl => $_key['weak_ssl'],
        before   => $_before,
      }
    }
  }
}
