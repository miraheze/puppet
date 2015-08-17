# class logrotate::rotate
#
# Simple class to help make logrotation files easily
class logrotate::rotate(
    $logs   = undef,
    $time   = 'weekly',
    $rotate = '52',
) {
    file { 'log_rotate_${title}':
        ensure  => present,
        path    => "/etc/logrotate.d/${title}",
        content => template('logrotate/logrotate'),
    }
}
        
