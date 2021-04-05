# @summary Manages Apt pins. Does not trigger an apt-get update run.
#
# @see http://linux.die.net/man/5/apt_preferences for context on these parameters
#
# @param ensure
#   Specifies whether the pin should exist. Valid options: 'file', 'present', and 'absent'.
#
# @param explanation
#   Supplies a comment to explain the pin. Default: "${caller_module_name}: ${name}".
#
# @param order
#   Determines the order in which Apt processes the pin file. Files with lower order numbers are loaded first.
#
# @param packages
#   Specifies which package(s) to pin.
#
# @param priority
#   Sets the priority of the package. If multiple versions of a given package are available, `apt-get` installs the one with the highest 
#   priority number (subject to dependency constraints). Valid options: an integer.
#
# @param release
#   Tells APT to prefer packages that support the specified release. Typical values include 'stable', 'testing', and 'unstable'.
#
# @param release_version
#   Tells APT to prefer packages that support the specified operating system release version (such as Debian release version 7).
#
# @param component
#   Names the licensing component associated with the packages in the directory tree of the Release file.
#
# @param originator
#   Names the originator of the packages in the directory tree of the Release file.
#
# @param label
#   Names the label of the packages in the directory tree of the Release file.
#
define apt::pin(
  Optional[Enum['file', 'present', 'absent']] $ensure = present,
  Optional[String] $explanation                       = undef,
  Variant[Integer] $order                             = 50,
  Variant[String, Array] $packages                    = '*',
  Variant[Numeric, String] $priority                  = 0,
  Optional[String] $release                           = '', # a=
  Optional[String] $origin                            = '',
  Optional[String] $version                           = '',
  Optional[String] $codename                          = '', # n=
  Optional[String] $release_version                   = '', # v=
  Optional[String] $component                         = '', # c=
  Optional[String] $originator                        = '', # o=
  Optional[String] $label                             = '',  # l=
) {

  if $explanation {
    $_explanation = $explanation
  } else {
    if defined('$caller_module_name') { # strict vars check
      $_explanation = "${caller_module_name}: ${name}"
    } else {
      $_explanation = ": ${name}"
    }
  }

  $pin_release_array = [
    $release,
    $codename,
    $release_version,
    $component,
    $originator,
    $label,
  ]
  $pin_release = join($pin_release_array, '')

  # Read the manpage 'apt_preferences(5)', especially the chapter
  # 'The Effect of APT Preferences' to understand the following logic
  # and the difference between specific and general form
  if $packages =~ Array {
    $packages_string = join($packages, ' ')
  } else {
    $packages_string = $packages
  }

  if $packages_string != '*' { # specific form
    if ( $pin_release != '' and ( $origin != '' or $version != '' )) or
      ( $version != '' and ( $pin_release != '' or $origin != '' )) {
      fail('parameters release, origin, and version are mutually exclusive')
    }
  } else { # general form
    if $version != '' {
      fail('parameter version cannot be used in general form')
    }
    if ( $pin_release != '' and $origin != '' ) {
      fail('parameters release and origin are mutually exclusive')
    }
  }

  # According to man 5 apt_preferences:
  # The files have either no or "pref" as filename extension
  # and only contain alphanumeric, hyphen (-), underscore (_) and period
  # (.) characters. Otherwise APT will print a notice that it has ignored a
  # file, unless that file matches a pattern in the
  # Dir::Ignore-Files-Silently configuration list - in which case it will
  # be silently ignored.
  $file_name = regsubst($title, '[^0-9a-z\-_\.]', '_', 'IG')

  $headertmp = epp('apt/_header.epp')

  $pinpreftmp = epp('apt/pin.pref.epp', {
      'name'            => $name,
      'pin_release'     => $pin_release,
      'release'         => $release,
      'codename'        => $codename,
      'release_version' => $release_version,
      'component'       => $component,
      'originator'      => $originator,
      'label'           => $label,
      'version'         => $version,
      'origin'          => $origin,
      'explanation'     => $_explanation,
      'packages_string' => $packages_string,
      'priority'        => $priority,
  })

  apt::setting { "pref-${file_name}":
    ensure        => $ensure,
    priority      => $order,
    content       => "${headertmp}${pinpreftmp}",
    notify_update => false,
  }
}
