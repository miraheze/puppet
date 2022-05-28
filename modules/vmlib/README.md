# vmflib

Custom Puppet functions and types that help you get things done.

Some of this functions are from https://github.com/wikimedia/puppet/tree/production/modules/wmflib

# Types

## VMlib::Ensure
Accepts either 'present' or 'absent' as values.
Should be used to validate standard ensure parameters, instead of the
corresponding `validate_ensure` function.

## VMlib::Sourceurl
Ensures the provided string begins with puppet:///modules/. This is useful to
validate the format of `source` arguments to file resources.

# Functions


## ensure_directory

`ensure_directory( string|bool $ensure )`

Takes a generic 'ensure' parameter value and convert it to an
appropriate value for use with a directory declaration.

If $ensure is 'true' or 'present', the return value is 'directory'.
Otherwise, the return value is the unmodified $ensure parameter.

### Examples

    # Sample class which creates or removes '/srv/redis'
    # based on the class's generic $ensure parameter:
    class redis( $ensure = present ) {
        package { 'redis-server':
            ensure => $ensure,
        }

        file { '/srv/redis':
          ensure => ensure_directory($ensure),
        }
    }


## ensure_link

`ensure_link( string|bool $ensure )`

Takes a generic 'ensure' parameter value and convert it to an
appropriate value for use with a symlink file declaration.

If $ensure is 'true' or 'present', the return value is 'link'.
Otherwise, the return value is the unmodified $ensure parameter.

### Examples

    # Sample class which creates or remove a symlink
    # based on the class's generic $ensure parameter:
    class rsyslog( $ensure = present ) {
        package { 'rsyslog':
            ensure => $ensure,
        }

        file { '/etc/rsyslog.d/50-default.conf':
            ensure => ensure_link($ensure),
            target => '/usr/share/rsyslog/50-default.conf',
        }
    }


## ensure_service

`ensure_service( string|bool $ensure )`

Takes a generic 'ensure' parameter value and convert it to an
appropriate value for use with a service declaration.

If $ensure is 'true' or 'present', the return value is 'running'.
Otherwise, the return value is 'stopped'.

### Examples

    # Sample class which starts or stops the redis service
    # based on the class's generic $ensure parameter:
    class redis( $ensure = present ) {
        package { 'redis-server':
            ensure => $ensure,
        }
        service { 'redis':
            ensure  => ensure_service($ensure),
            require => Package['redis-server'],
        }
    }


## ini

`ini( hash $ini_settings [, hash $... ] )`

Serialize a hash into the .ini-style format expected by Python's
ConfigParser. Takes one or more hashes as arguments. If the argument
list contains more than one hash, they are merged together. In case of
duplicate keys, hashes to the right win.

### Example

    ini({'server' => {'port' => 80}})

will produce:

    [server]
    port = 80


## ordered_json

`ordered_json( hash $data [, hash $... ] )`

Serialize a hash into JSON with lexicographically sorted keys.

Because the order of keys in Ruby 1.8 hashes is undefined, 'to_pson'
is not idempotent: i.e., the serialized form of the same hash object
can vary from one invocation to the next. This causes problems
whenever a JSON-serialized hash is included in a file template,
because the variations in key order are picked up as file updates by
Puppet, causing Puppet to replace the file and refresh dependent
resources on every run.

### Examples

    # Render a Puppet hash as a configuration file:
    $options = { 'useGraphite' => true, 'minVal' => '0.1' }
    file { '/etc/kibana/config.json':
        content => ordered_json($options),
    }

## os_version

`os_version( string $version_predicate )`

Performs semantic OS version comparison.

Takes one or more string arguments, each containing one or more predicate
expressions. Each expression consts of a distribution name, followed by a
comparison operator, followed by a release name or number. Multiple clauses
are OR'd together. The arguments are case-insensitive.

The host's OS version will be compared to to the comparison target
using the specified operator, returning a boolean. If no operator is
present, the equality operator is assumed.

### Examples

    # True if Ubuntu Trusty or newer or Debian jessie or newer
    os_version('ubuntu >= trusty || debian >= jessie')

    # True if exactly Debian Jessie
    os_version('debian jessie')


## php_ini

`php_ini( hash $ini_settings [, hash $... ] )`

Serialize a hash into php.ini-style format. Takes one or more hashes as
arguments. If the argument list contains more than one hash, they are
merged together. In case of duplicate keys, hashes to the right win.

### Example

    php_ini({'server' => {'port' => 80}}) # => server.port = 80


## requires_os

`requires_os( string $version_predicate )`

Validate that the host OS version satisfies a version
check. Abort catalog compilation if not.

See the documentation for os_version() for supported
predicate syntax.

### Examples

    # Fail unless version is Trusty or Jessie
    requires_os('ubuntu trusty || debian jessie')

    # Fail unless Trusty or newer
    requires_os('ubuntu >= trusty')


## ssl_ciphersuite

`ssl_ciphersuite( string $servercode, string $encryption_type, boolean $hsts )`

Outputs the ssl configuration directives for use with either Nginx
or Apache using our selection of ciphers and SSL options.

Takes three arguments:

- The server to configure for: 'apache' or 'nginx'
- The compatibility mode,indicating the degree of compatibility we
  want to retain with older browsers (basically, IE6, IE7 and
  Android prior to 3.0)
- hsts - optional boolean, true emits our standard public HSTS

Whenever called, this function will output a list of strings that
can be safely used in your configuration file as the ssl
configuration part.

### Examples

    ssl_ciphersuite('apache', 'compat', true)
    ssl_ciphersuite('nginx', 'strong')


## validate_ensure
`validate_ensure( string $ensure )`

Throw an error if the $ensure argument is not 'present' or 'absent'.

### Examples

    # Abort compilation if $ensure is invalid
    validate_ensure($ensure)
