# class: irc::ircrcbot
class irc::ircrcbot(
    $nickname     = undef,
    $password     = undef,
    $network      = undef,
    $network_port = '6667',
    $channel      = undef,
    $udp_port     = '5070',
    $sleeptime    = '0.5',
) {
    include ::irc
    
    file { '/usr/local/bin/ircrcbot.py':
        ensure  => present,
        content => template('irc/ircrcbot.py'),
    }
}
