# == Class zookeeper::install::repo
#
# This class manages yum repository for Zookeeper packages
#
# @private - do not use directly (use main `zookeeper` class).
class zookeeper::install::repo inherits zookeeper::install {
  if $zookeeper::repo {
    case $facts['os']['family'] {
      'RedHat', 'Suse': {
        $_config = $zookeeper::repo
        if $_config['name'] == undef or $_config['url'] == undef or $_config['descr'] == undef {
          fail('Invalid parameter settings for custom repo')
        }
        # Puppet 4 compatibility: force variable to be a String
        yumrepo { $_config['name']:
          ensure    => $zookeeper::ensure,
          descr     => $_config['descr'],
          baseurl   => $_config['url'],
          enabled   => 1,
          sslverify => empty($_config['sslverify']) ? {
            true  => 0,
            false => $_config['sslverify']
          },
          gpgcheck  => empty($_config['gpgcheck']) ? {
            true  => 0,
            false => $_config['gpgcheck']
          },
        }
      }
      default: {
        fail("\"${module_name}\" doesn't support repository for ${facts['os']['family']} yet.")
      }
    }
  }
}
