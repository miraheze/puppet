# == Define: php::fpm::pool
#
# Configures an fpm pool.
# You need to declare the class php::fpm before you use this define.
#
# === Usage
#
# php::fpm::pool { 'mediawiki':
#     port   => 8000,
#     config => { 'pm.max_children' => 128 },
# }
#
# === Parameters
# [*filename*] The name of the file to install. Defaults to $title
#
# [*port*]
#   If defined, the TCP port (on localhost) the pool will be listening on.
#   If not, the pool will listen on a unix socket at
#   '/run/php/fpm-<title_safe>.sock'. Defaults to undef.
#
# [*user*]
#   The user the pool will run as. Defaults to www-data.
#
# [*group*]
#   The group the pool will run as. Defaults to www-data.
#
# [*config*]
#   Any additional config, in the form of a k => v hash, to merge with the
#   default one. Defaults to an empty hash.
#
define php::fpm::pool(
    String $filename = $title,
    Optional[Stdlib::Port] $port = undef,
    String $user = 'www-data',
    String $group = 'www-data',
    Hash $config = {},
){
    if !defined(Class['php::fpm']) {
        fail('php::fpm::pools can only be configured if php::fpm is defined')
    }

    $title_safe  = regsubst($title, '[\W_]', '-', 'G')
    $filename_safe = regsubst($filename, '[^\w\.]', '-', 'G')
    if $port == undef {
        $listen = "/run/php/fpm-${title_safe}.sock"
    } else {
        $listen = "127.0.0.1:${port}"
    }

    $base_config = {
        'user'   => $user,
        'group'  => $group,
        'listen' => $listen,
        'listen.owner' => $user,
        'listen.group' => $group,
        'listen.allowed_clients' => '127.0.0.1',
        'listen.backlog' => 256,
        'pm'     => 'static',
        'pm.max_children' => $facts['processors']['count'],
        'pm.max_requests' => 5000,
        'pm.status_path' => '/php_status',
        'access.format'  => '%{%Y-%m-%dT%H:%M:%S}t [%p] %{microseconds}d %{HTTP_HOST}e/%r %m/%s %{mega}M',
        'process.dumpable' => yes,
        'request_slowlog_timeout' => 15,
        'slowlog' => "/var/log/php${php::version}-fpm-${title_safe}-slowlog.log",
    }


    $pool_config = merge($base_config, $config)
    file { "${php::config_dir}/fpm/pool.d/${filename_safe}.conf":
        content => template("php/php${php::version}-fpm.pool.conf.erb"),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        notify  => Service["php${php::version}-fpm"]
    }

    # Configure rsyslog to monitor the php slowlog file and send the log messages to Graylog
    rsyslog::input::file { 'php-slowlog':
        path              => "/var/log/php${php::version}-fpm-${title_safe}-slowlog.log",
        syslog_tag_prefix => '',
        use_udp           => true,
    }
}
