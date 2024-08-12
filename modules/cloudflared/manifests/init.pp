# cloudflared
#
# Main class, includes all other classes
#
# @param package_manage
#   Whether or not this puppet module will manage the cloudflared package
#   Default: true
#
# @param package_name
#   Name of the cloudflared package
#   Default: 'cloudflared'
#
# @param package_ensure
#   Whether to install the cloudflared package
#   Default value: 'present'

class cloudflared (
  Boolean $package_manage,
  String $package_name,
  String $package_ensure,
) {
  contain cloudflared::install

  Class['cloudflared::install']
}
