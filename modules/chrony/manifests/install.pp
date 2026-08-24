# @summary Installs chrony
#
# @api private
class chrony::install {
  assert_private()

  package { 'chrony':
    ensure   => $chrony::package_ensure,
    name     => $chrony::package_name,
    source   => $chrony::package_source,
    provider => $chrony::package_provider,
  }
}
