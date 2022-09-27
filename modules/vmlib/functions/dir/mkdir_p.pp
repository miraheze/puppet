# @summary Like the unix command `mkdir -p` except with puppet code.
# This creates file resources for all directories returned by vmlib::dir::split.  you can also
# pass a parameteres hash of file resource paramters which will be applied to the target dirs
#
# @param dirs  the path(s) to create
# @param params the resource parameters to apply to dirs
# @example creating directories
#  vmlib::dir::mkdir_p('/opt/puppetlabs/bin') will create:
#  file{['/opt', '/opt/puppetlabs', '/opt/puppetlabs/bin']: ensure => directory}
# @example creating directories with additional properties
#  vmlib::dir::mkdir_p('/opt/puppetlabs/bin', {owner => 'foobar'}) will create:
#  file{['/opt', '/opt/puppetlabs']: ensure => directory}
#  file{['/opt', '/opt/puppetlabs']:
#    ensure => directory,
#	 owner  => 'foobar',
#  }
function vmlib::dir::mkdir_p(
    Variant[Stdlib::Unixpath, Array[Stdlib::Unixpath]] $dirs,
    Hash                                               $params = {},
) {
    $_dirs = vmlib::dir::normalise($dirs)
    $parents = vmlib::dir::split($_dirs) - $_dirs
    # ensure all parent directories exist
    ensure_resource('file', $parents, {'ensure' => 'directory'})
    # Apply params only to the actual directories
    ensure_resource('file', $dirs, {'ensure' => 'directory'} + $params)
}

