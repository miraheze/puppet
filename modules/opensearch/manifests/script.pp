#  This define allows you to insert, update or delete scripts that are used
#  within Opensearch.
#
# @param ensure
#   Controls the state of the script file resource to manage.
#   Values are simply passed through to the `file` resource.
#
# @param recurse
#   Will be passed through to the script file resource.
#
# @param source
#   Puppet source of the script
#
# @author Richard Pijnenburg <richard.pijnenburg@elasticsearch.com>
# @author Tyler Langlois <tyler.langlois@elastic.co>
#
define opensearch::script (
  String                                     $source,
  String                                     $ensure  = 'present',
  Optional[Variant[Boolean, Enum['remote']]] $recurse = undef,
) {
  if ! defined(Class['opensearch']) {
    fail('You must include the Opensearch base class before using defined resources')
  }

  $filename_array = split($source, '/')
  $basefilename = $filename_array[-1]

  file { "${opensearch::homedir}/scripts/${basefilename}":
    ensure  => $ensure,
    source  => $source,
    owner   => $opensearch::opensearch_user,
    group   => $opensearch::opensearch_group,
    recurse => $recurse,
    mode    => '0644',
  }
}
