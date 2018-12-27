# = Class: profile::puppetserver
#
# Sets up a puppetserver for all puppet agent's to connect to.
#
class profile::puppetserver (
    String  $puppetdb_hostname      = hiera('puppetdb_hostname', 'puppet1.miraheze.org'),
    Boolean $puppetdb_enable        = hiera('puppetdb_enable', false),
    Integer $puppet_major_version   = hiera('puppet_major_version', 6),
    String  $puppetserver_hostname  = hiera('puppetserver_hostname', 'puppet1.miraheze.org'),
    String  $puppetserver_java_opts = hiera('puppetserver_java_opts', '-Xms300m -Xmx300m'),
) {
    class { '::puppetserver':
        puppetdb_hostname      => $puppetdb_hostname,
        puppetdb_enable        => $puppetdb_enable,
        puppet_major_version   => $puppet_major_version,
        puppetserver_hostname  => $puppetserver_hostname ,
        puppetserver_java_opts => $puppetserver_java_opts,
    }
}
