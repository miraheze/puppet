# == Class: icinga2::repo
#
# This class manages the packages.icinga.com repository based on the operating system. Windows is not supported, as the
# Icinga Project does not offer a chocolate repository.
#
# === Parameters
#
# This class does not provide any parameters.
# To control the behaviour of this class, have a look at the parameters:
# * icinga2::manage_repo
#
# === Examples
#
# This class is private and should not be called by others than this module.
#
#
class icinga2::repo {

  assert_private()

  if $::icinga2::manage_repo and $::icinga2::manage_package {
    $repo =  lookup('icinga2::repo', Hash, 'deep', {})

    # handle icinga stable repo before all package resources
    # contain class problem!
    Apt::Source['icinga-stable-release'] -> Package <| tag == 'icinga2' |>
    Class['Apt::Update'] -> Package<|tag == 'icinga2'|>

    include ::apt
    apt::source { 'icinga-stable-release':
      * => $repo,
    }
  } # if $::icinga::manage_repo

}
