# @summary
# This class manages the stages stable, testing and snapshot of packages.icinga.com repository
# and depending on the operating system platform some other repositories.
#
# @param [Boolean] manage_stable
#   Manage the Icinga stable repository. Disabled by setting to 'false'. Defaults to 'true'.
#
# @param [Boolean] manage_testing
#   Manage the Icinga testing repository to get access to release candidates.
#   Enabled by setting to 'true'. Defaults to 'false'.
#
# @param [Boolean] manage_nightly
#   Manage the Icinga snapshot repository to get access to nightly snapshots.
#   Enabled by setting to 'true'. Defaults to 'false'.
#
# @param [Boolean] configure_backports
#   Enables or Disables the backports repository. Has only an effect on plattforms
#   simular to Debian. To configure the backports repo uses apt::backports in hiera.
#
# @param [Boolean] manage_epel
#   Manage the EPEL (Extra Packages Enterprise Linux) repository that is needed for some package
#   like newer Boost libraries. Has only an effect on plattforms simular to RedHat Enterprise.
#
# @param [Boolean] manage_powertools
#   Manage the PowerTools repository that is needed for some package like nagios-plugins on
#   Linux Enterprise systems like Alma, Rocky and CentOS Stream.
#
# @param [Boolean] manage_server_monitoring
#   Manage the 'server:monitoring' repository on SLES platforms that is needed for some package
#   like monitoring-plugins-common. Additional also the 'monitoring-plugins' are provided by this
#   repository. Bye default the repository is added with a lower priority of 120.
#
# @param [Boolean] manage_plugins
#   Manage the NETWAYS plugins repository that provides some packages for additional plugins.
#
# @param [Boolean] manage_extras
#   Manage the NETWAYS extras repository that provides some packages for extras.
#
# @example
#   require icinga::repos
#
class icinga::repos(
  Boolean $manage_stable,
  Boolean $manage_testing,
  Boolean $manage_nightly,
  Boolean $configure_backports,
  Boolean $manage_epel,
  Boolean $manage_powertools,
  Boolean $manage_server_monitoring,
  Boolean $manage_plugins,
  Boolean $manage_extras,
) {

  $list    =  lookup('icinga::repos', Hash, 'deep', {})
  $managed = {
    icinga-stable-release   => $manage_stable,
    icinga-testing-builds   => $manage_testing,
    icinga-snapshot-builds  => $manage_nightly,
    epel                    => $manage_epel,
    powertools              => $manage_powertools,
    server_monitoring       => $manage_server_monitoring,
    netways-plugins-release => $manage_plugins,
    netways-extras-release  => $manage_extras,
  }

  contain ::icinga::repos::apt

}
