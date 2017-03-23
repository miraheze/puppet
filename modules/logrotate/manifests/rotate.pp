# define logrotate::rotate
#
# Simple class to help make logrotation files easily
define logrotate::rotate(
    $logs   = undef,
    $time   = 'weekly',
    $rotate = '12',
    $delay  = true,
) {
    file { "log_rotate_${title}":
        ensure  => present,
        path    => "/etc/logrotate.d/${title}",
        content => template('logrotate/logrotate'),
    }
}
