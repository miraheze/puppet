# define logrotate::rotate
#
# Simple class to help make logrotation files easily
define logrotate::rotate(
    Optional[String] $logs   = undef,
    Enum['daily', 'weekly', 'monthly'] $time   = 'weekly',
    String $rotate = '12',
    Boolean $delay  = true,
) {
    file { "log_rotate_${title}":
        ensure  => present,
        path    => "/etc/logrotate.d/${title}",
        content => template('logrotate/logrotate.erb'),
    }
}
