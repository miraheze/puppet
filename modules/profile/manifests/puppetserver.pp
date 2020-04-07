# = Class: profile::puppetserver
#
# Sets up a puppetserver for all puppet agent's to connect to.
#
class profile::puppetserver (
    String  $puppetdb_hostname      = lookup('puppetdb_hostname', 'puppet2.miraheze.org'),
    Boolean $puppetdb_enable        = lookup('puppetdb_enable', false),
    Integer $puppet_major_version   = lookup('puppet_major_version', 6),
    String  $puppetserver_hostname  = lookup('puppetserver_hostname', 'puppet2.miraheze.org'),
    String  $puppetserver_java_opts = lookup('puppetserver_java_opts', '-Xms300m -Xmx300m'),
) {
    class { '::puppetserver':
        puppetdb_hostname      => $puppetdb_hostname,
        puppetdb_enable        => $puppetdb_enable,
        puppet_major_version   => $puppet_major_version,
        puppetserver_hostname  => $puppetserver_hostname ,
        puppetserver_java_opts => $puppetserver_java_opts,
    }
}
